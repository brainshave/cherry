fs       = require './io'
_        = require 'underscore'
{do_all} = require './flow'

needs_recompile = (output, callback) ->
  check = (err, stats) ->
    if err
      callback err
      return

    output_mtime = stats.shift().mtime
    if not output_mtime
      callback null, true
      return

    for mtime in _.pluck stats, 'mtime'
      if not mtime or mtime > output_mtime
        callback null, true
        return
    callback null, false

  check_all = do_all (path, callback) ->
    fs.exists path, (exists) ->
      if exists
        fs.stat path, callback
      else
        callback null, {}

  check_all.call null, [output.path, output.deps...], check

build_nexts = (output_path, outputs, built_all_callback) ->
  output = outputs[output_path]
  for next_path in output.nexts
    next = outputs[next_path]
    next.awaiting = _.without next.awaiting, output_path
    build_one next_path, outputs, built_all_callback

gen_final_callback = (output_path, outputs, built_all_callback) -> (err) ->
  output = outputs[output_path]
  if err
    console.error "Error while building #{output_path}:\n", err.stack or err
  else
    console.log "Built #{output_path}"
    done output_path, outputs, built_all_callback

building = 0

done = (output_path, outputs, built_all_callback) ->
  output = outputs[output_path]
  build_nexts output_path, outputs, built_all_callback
  building--
  if building is 0
    console.log 'Built all targets.'
    if typeof built_all_callback is 'function'
      built_all_callback()

build_one = (output_path, outputs, built_all_callback) ->
  output = outputs[output_path]

  output.building = true

  if output.awaiting.length isnt 0
    console.log "Target #{output_path} is waiting for #{output.awaiting.join ', '}"
    return

  building++

  needs_recompile output, (err, recompile) ->
    if err
      console.error "Error while checking dates of deps for #{output_path}:"
      console.error err.stack or err
      return

    if recompile
      console.log "Building #{output_path} from #{output.deps.join(', ')}"
      callback = gen_final_callback output_path, outputs, built_all_callback
      try
        output.recipe.run.call output, output.deps, callback
      catch error
        callback error

    else
      console.log "Target #{output_path} is already up to date."
      done output_path, outputs

build = (outputs, callback) ->
  for own output_path of outputs
    build_one output_path, outputs, callback

build.help = 'Builds all targets'

module.exports =
  build:     build
  build_one: build_one
