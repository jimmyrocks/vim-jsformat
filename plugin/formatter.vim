"% Preliminary validation of global variables
"  and version of the editor.

if v:version < 700
  finish
endif

" check whether this script is already loaded
if exists('g:loaded_Formatter')
  finish
endif

let g:loaded_Formatter = 1

if !exists('g:config_Formatter')
  let g:config_Formatter = {}
endif

if !exists('g:editorconfig_Formatter')
  let g:editorconfig_Formatter = ''
endif

" temporary file for content
if !exists('g:tmp_file_Formatter')
  let g:tmp_file_Formatter = fnameescape(tempname())
endif

" Which file types supported vim plugin
" Default settings for this file types you can see
" in file plugin/.editorconfig
let s:supportedFileTypes = ['js', 'python']

"% Helper functions and variables
let s:plugin_Root_directory = fnamemodify(expand("<sfile>"), ":h")
let s:paths_Editorconfig = map(['$HOME/.editorconfig', '$HOME/.vim/.editorconfig', s:plugin_Root_directory.'/.editorconfig'], 'expand(v:val)')

" Function for debugging
" @param {Any} content Any type which will be converted
" to string and write to tmp file
func! s:console(content)
  let log_dir = fnameescape('/tmp/vimlog')
  call writefile([string(a:content)], log_dir)
  return 1
endfun

" Output warning message
" @param {Any} message The warning message
fun! WarningMsg(message)
  echohl WarningMsg
  echo string(a:message)
endfun

" Output error message
" @param {Any} message The error message
fun! ErrorMsg(message)
  echoerr string(a:message)
endfun

" Check type of files
" @param {String} type The verified type
" @param {[List]} The list of allowed types
"
" @return {Boolean} Is the type in list of allowed types
func! s:isAllowedType(type, ...)
  let haz = 1
  let type = a:type
  let allowedTypes = get(a:000, 1, s:supportedFileTypes)

  return index(allowedTypes, type) != -1
endfun

" Quoting string
" @param {String} str Any string
" @return {String} The quoted string
func! s:quote(str)
  return '"'.escape(a:str,'"').'"'
endfun

" convert string to JSON
" @param {String} str Any string
" @return {String} The JSON string
func! s:toJSON(str)
  let json = substitute(a:str, "'[", '[', 'g')
  let json = substitute(json, "]'", ']', 'g')

  let json = substitute(json, "'false'", 'false', 'g')
  let json = substitute(json, "'true'", 'true', 'g')

  let json = substitute(json, "'", '"', 'g')
  let json = s:quote(json)
  return json
endfun

" @param {String} The content of .editorconfig file
" @return {Dict} The configuration object based
" on content the file.
func! s:processingEditconfigFile(content)
  let opts = {}
  let content = a:content

  for type in s:supportedFileTypes
    " Get settings for javascript files
    " collect all data after [**.js] to
    " empty string
    let index = index(content, '[**.'.type.']')
    let l:value = {}

    if index == -1
      " If section doesn't define then set it how
      " empty object
      " @fix issue-25
      let opts[type] = l:value
      continue
    endif

    " line with declaration [**.type]
    " we shoul skip.
    let index = index + 1
    let line = get(content, index)

    " if string start with bracket
    " then we assumes that it's
    " start new logical section
    " and break processing
    while (strpart(line, 0, 1) != '[' && index <= len(content))

      if (!empty(matchstr(line, ';\(vim:\)\@!')) || empty(line))
        " if we meet comment which is don't
        " special comment or empty string
        " then stop processing this line
        let index = index + 1
        let line = get(content, index)
        continue
      endif

      " special comment should look like
      " ';vim:key=value:second=value'
      if strpart(line, 0, 1) == ';'
        " if it's special comment then procesisng
        " it separate and continue processing
        let l:copts = split(strpart(line, 5), ':')

        for part in l:copts
          let data = split(part, '\s*=\s*')
          let l:value[get(data, 0)] = get(data, 1)
        endfor
      else
        " else we assumes that it is
        " .editorconfig setting
        let data = split(line, '\s*=\s*')
        let l:value[get(data, 0)] = get(data, 1)
      endif

      let index = index + 1
      let line = get(content, index)
    endwhile

    let opts[type] = l:value
  endfor

  return opts
endfun

" Convert some property from editorconfig
" to js-beautifier. For example `tab`.
"
" param {Dict} value The configuration object.
" return {Dict} Return the same configuration object.
function s:treatConfig(config)
  let config = a:config

  if has_key(config, 'indent_style')
    if config["indent_style"] == 'space'
      let config["indent_char"] = ' '
    elseif config["indent_style"] == 'tab'
      let config["indent_char"] = '\t'
      " When the indent_char is tab, we always want to use 1 tab
      let config["indent_size"] = 1
    endif
  endif

  if has_key(config, 'insert_final_newline')
      let config["end_with_newline"] = config["insert_final_newline"]
  endif

  return config
endfunction

" ÐœÐµÑ‚Ð¾Ð´ ÐºÐ¾Ñ‚Ð¾Ñ€Ñ‹Ðµ Ð¾Ð±Ð½Ð¾Ð²Ð»ÑÐµÑ‚
" ÑÐºÑ€Ð¸Ð¿Ñ‚Ð¾Ð²Ð¾Ð¹ 'Ð¿Ñ€Ð¸Ð²Ð°Ñ‚Ð½Ñ‹Ð¹' Ð¾Ð±ÑŠÐµÐºÑ‚
" ÐºÐ¾Ð½Ñ„Ð¸Ð³ÑƒÑ€Ð°Ñ†Ð¸Ð¸
"
" param {Dict} value The configuration object.
" return {Dict} Return copy of configuration obect with link on
" old config or empty object.
function s:updateConfig(value)
  if empty(a:value)
    return a:value
  endif

  let config = deepcopy(a:value)

  for type in s:supportedFileTypes
    if has_key(config, type)
      call s:treatConfig(config[type])
    endif
  endfor

  " Ð”ÐµÐ»Ð°ÐµÐ¼ ÐºÐ¾Ð¿Ð¸ÑŽ Ð¾Ð±ÑŠÐµÐºÑ‚Ð°
  let b:config_Formatter = config

  return b:config_Formatter
endfunction

" Get default path
" @param {String} type Some of the types js, html or css
func s:getPathByType(type)
  let type = a:type
  let rootPtah = s:plugin_Root_directory
  let path = rootPtah."format.js"
  return path
endfunc



" Helper functions for restoring mark and cursor position
function! s:getNumberOfNonSpaceCharactersFromTheStartOfFile(position)
  let cursorRow = a:position.line
  let cursorColumn = a:position.column
  let lineNumber = 1
  let nonBlankCount = 0
  while lineNumber <= cursorRow
    let lineContent = getline(lineNumber)
    if lineNumber == cursorRow
      let lineContent = strpart(lineContent,0,cursorColumn)
    endif
    let charIndex = 0
    while charIndex < len(lineContent)
      let char = strpart(lineContent,charIndex,1)
      if match(char,'\s\|\n\|\r') == -1
        let nonBlankCount = nonBlankCount + 1
      endif
      let charIndex = charIndex + 1
    endwhile
    "echo nonBlankCount
    let lineNumber = lineNumber + 1
  endwhile
  return nonBlankCount
endfunction



"Converts number of non blank characters to cursor position (line and column)
function! s:getCursorPosition(numberOfNonBlankCharactersFromTheStartOfFile)
  let lineNumber = 1
  let nonBlankCount = 0
  while lineNumber <= line('$')
    let lineContent = getline(lineNumber)
    let charIndex = 0
    while charIndex < len(lineContent)
      let char = strpart(lineContent,charIndex,1)
      if match(char,'\s\|\n\|\r') == -1
        let nonBlankCount = nonBlankCount + 1
      endif
      let charIndex = charIndex + 1
      if nonBlankCount == a:numberOfNonBlankCharactersFromTheStartOfFile 
        "Found position!
        return {'line': lineNumber,'column': charIndex}
      end
    endwhile
    let lineNumber = lineNumber + 1
  endwhile

  "Oops, nothing found!
  return {}
endfunction



"Restoring current position by number of non blank characters
function! s:setNumberOfNonSpaceCharactersBeforeCursor(mark,numberOfNonBlankCharactersFromTheStartOfFile)
  let location = s:getCursorPosition(a:numberOfNonBlankCharactersFromTheStartOfFile)

  if !empty(location)
      call setpos(a:mark, [0, location.line, location.column, 0])
  endif
endfunction



function! s:getCursorAndMarksPositions()
  let localMarks = map(range(char2nr('a'), char2nr('z'))," \"'\".nr2char(v:val) ") 
  let marks = ['.'] + localMarks
  let result = {}
  for positionType in marks
    let cursorPositionAsList = getpos(positionType)
    let cursorPosition = {'buffer': cursorPositionAsList[0], 'line': cursorPositionAsList[1], 'column': cursorPositionAsList[2]}
    if cursorPosition.buffer == 0 && cursorPosition.line > 0
      let result[positionType] = cursorPosition
    endif
  endfor
  return result
endfunction




"% Declaring global variables and functions

" Apply settings from 'editorconfig' file to beautifier.
" @param {String} filepath path to configuration 'editorconfig' file.
" @return {Number} If apply was success then return '0' else '1'
function FormatterApplyConfig(...)

  " ÐŸÐ¾Ð»ÑƒÑ‡Ð°ÐµÐ¼ Ð¿ÑƒÑ‚ÑŒ ÐºÐ¾Ñ‚Ð¾Ñ€Ñ‹Ð¹ Ð½Ð°Ð¼ Ð¿ÐµÑ€ÐµÐ´Ð°Ð»Ð¸
  let l:filepath = get(a:000, 0)

  " ÐŸÑ€Ð¾Ñ…Ð¾Ð´Ð¸Ð¼ÑÑ Ð¿Ð¾ Ð´ÐµÑ„Ð¾Ð»Ñ‚Ð½Ñ‹Ð¼ Ð¿ÑƒÑ‚ÑÐ¼ Ñ‚Ð¾Ð»ÑŒÐºÐ¾ ÐµÑÐ»Ð¸
  " Ð¾ÐºÐ°Ð·Ð°Ð»Ð¾ÑÑŒ Ñ‡Ñ‚Ð¾ Ð½Ð°Ð¼ Ð½Ðµ Ð¿ÐµÑ€ÐµÐ´Ð°Ð»Ð¸ Ð¿ÑƒÑ‚ÑŒ
  "
  " Ð•ÑÐ»Ð¸ Ð½Ð°Ð¼ Ð¿ÐµÑ€ÐµÐ´Ð°Ð»Ð¸ Ð¿ÑƒÑ‚ÑŒ Ñ‚Ð¾ Ð½Ðµ ÑÑ‚Ð¾Ð¸Ñ‚ ÐµÐ³Ð¾
  " Ñ‚ÑƒÑ‚ Ð¿Ñ€Ð¾Ð²ÐµÑ€ÑÑ‚ÑŒ Ð½Ð° ÑÑƒÑˆÐµÑÑ‚Ð²Ð¾Ð²Ð°Ð½Ð¸Ðµ
  if empty(l:filepath)
    let l:filepath = get(filter(copy(s:paths_Editorconfig),'filereadable(v:val)'), 0)
  endif

  if !filereadable(l:filepath)
    " File doesn't exist then return '1'
    call WarningMsg('Can not find global .editorconfig file!')
    return 1
  endif


  let l:content = readfile(l:filepath)

  " Process .editorconfig file
  let opts = s:processingEditconfigFile(l:content)

  let g:config_Formatter = opts
  call s:updateConfig(opts)

  " All Ok! return '0'
  return 0
endfunction


" Common function for beautify
" @param {String} type The type of file js, css, html
" @param {[String]} line1 The start line from which will start
" formating text, by default '1'
" @param {[String]} line2 The end line on which stop formating,
" by default '$'
func! Formatter(...)
  let cursorPositions = s:getCursorAndMarksPositions()
  call map(cursorPositions, " extend (v:val,{'characters': s:getNumberOfNonSpaceCharactersFromTheStartOfFile(v:val)}) ")
  if !exists('b:config_Formatter')
    call s:updateConfig(g:config_Formatter)
  endif

  " Define type of file
  let type = get(a:000, 0, expand('%:e'))
  let allowedTypes = get(b:config_Formatter[type], 'extensions')

  if !s:isAllowedType(type, allowedTypes)
    call WarningMsg('File type is not allowed!')
    return 1
  endif

  let line1 = get(a:000, 1, '1')
  let line2 = get(a:000, 2, '$')

  let opts = b:config_Formatter[type]
  let path = get(opts, 'path', s:getPathByType(type))
  let path = expand(path)
  let path = fnameescape(path)
  " Get external engine which will
  " be execute javascript file
  " by default get nodejs
  let engine = get(opts, 'bin', 'nodejs')
  " nodejs may be called node
  if !executable(engine)
      let engine = get(opts, 'bin', 'node')
  endif

  " Get content from the files
  let content = getline(line1, line2)

  " Length of lines before beautify
  let lines_length = len(getline(line1, line2))

  " Write content to temporary file
  call writefile(content, g:tmp_file_Formatter)
  " String arguments which will be passed
  " to external command

  let opts_Formatter_arg = s:toJSON(string(opts))
  let path_Formatter_arg = s:quote(path)
  let tmp_file_Formatter_arg = s:quote(g:tmp_file_Formatter)

  if has("win32unix")  && executable("cygpath")
    let beautify_absolute_path_windows = fnameescape(system("cygpath -w ".s:plugin_Root_directory."/format.js"))
    let tmp_file_Formatter_arg_windows = fnameescape(system("cygpath -w ".tmp_file_Formatter_arg))
    let path_Formatter_arg_windows = fnameescape(system("cygpath -w ".path_Formatter_arg))

    let result = system(engine." ".beautify_absolute_path_windows." --js_arguments ".tmp_file_Formatter_arg_windows." ".opts_Formatter_arg." ".path_Formatter_arg_windows." ".type)
  elseif executable(engine)
    let result = system(engine." ".fnameescape(s:plugin_Root_directory."/format.js")." --js_arguments ".tmp_file_Formatter_arg." ".opts_Formatter_arg." ".path_Formatter_arg." ".type)
  else
    " Executable bin doesn't exist
    call ErrorMsg('The '.engine.' is not executable!')
    return 1
  endif

  let lines_Format = split(result, "\n")

  " issue 42
  if !len(lines_Format)
      return result
  endif

  " TODO(maksimrv): Find better solution for splitting result on lines
  " NOTE(maksimrv): This is need because if result contain newline in the end of file
  " then split simple remove last line
  if has_key(opts, 'end_with_newline')
      if opts["end_with_newline"] == 'true'
          let lines_Format =  lines_Format + ['']
      endif
  endif

  silent exec line1.",".line2."j"
  call setline(line1, lines_Format[0])
  call append(line1, lines_Format[1:])

  for [key,value] in items(cursorPositions)
    call s:setNumberOfNonSpaceCharactersBeforeCursor(key,value.characters)
  endfor
  return result
endfun

" editorconfig hook
" Intergration with editorconfig.
" https://github.com/editorconfig/editorconfig-vim.git
func! FormatterEditorconfigHook(config)
  let type = expand('%:e')
  let config = a:config

  if !(type(config) == 4)
    return 1
  endif

  if !s:isAllowedType(type)
    return 1
  endif


  " If buffer config variable does not exist
  " then let it
  if !exists('b:config_Formatter')
    let b:config_Formatter = deepcopy(g:config_Formatter)
  endif

  if !len(config)
    call s:updateConfig(g:config_Formatter)
    return 1
  endif

  let config = extend(b:config_Formatter[type], config)

  call s:treatConfig(config)

  let b:config_Formatter[type] = config

  " All Ok! retun 0
  return 0
endfun

" @param {[Number|String]} a:0 Default value '1'
" @param {[Number|String]} a:1 Default value '$'
fun! RangeJsFormat() range
  return call('Formatter', extend(['js'], [a:firstline, a:lastline]))
endfun

fun! JsFormat(...)
  return call('Formatter', extend(['js'], a:000))
endfun

fun! JsxFormat(...)
  return call('Formatter', extend(['jsx'], a:000))
endfun

fun! RangeJsxFormat() range
  return call('Formatter', extend(['jsx'], [a:firstline, a:lastline]))
endfun

fun! JsonFormat(...)
  return call('Formatter', extend(['json'], a:000))
endfun

fun! RangeJsonFormat() range
  return call('Formatter', extend(['json'], [a:firstline, a:lastline]))
endfun

fun! RangeHtmlFormat() range
  return call('Formatter', extend(['html'], [a:firstline, a:lastline]))
endfun

fun! HtmlFormat(...)
  return call('Formatter', extend(['html'], a:000))
endfun

fun! RangeCSSFormat() range
  return call('Formatter', extend(['css'], [a:firstline, a:lastline]))
endfun

fun! CSSFormat(...)
  return call('Formatter', extend(['css'], a:000))
endfun

fun! RangePythonFormat() range
  return call('Formatter', extend(['python'], [a:firstline, a:lastline]))
endfun

fun! PythonFormat(...)
  return call('Formatter', extend(['python'], a:000))
endfun


" Check if installed editorconfig plugin
" then add hook on change
try
  let FormatterHook = function('FormatterEditorconfigHook')
  call editorconfig#AddNewHook(FormatterHook)
catch
endt

"XXX: legacy block code
"yet retain support old config
fun! LegacyMsg()
  call WarningMsg('beautifier.vim#Please use .editorconfig for default settings')
endfun

if exists('g:jsbeautify')
  let g:config_Formatter['js'] = g:jsbeautify
  if exists('g:jsbeautify_file')
    let g:config_Formatter['js']['path'] = g:jsbeautify_file
  endif
  call LegacyMsg()
endif

if exists('g:htmlbeautify')
  let g:config_Formatter['html'] = g:htmlbeautify
  if exists('g:htmlbeautify_file')
    let g:config_Formatter['html']['path'] = g:htmlbeautify_file
  endif
  call LegacyMsg()
endif

if exists('g:htmlbeautify')
  let g:config_Formatter['css'] = g:cssbeautify
  if exists('g:cssbeautify_file')
    let g:config_Formatter['css']['path'] = g:cssbeautify_file
  endif
  call LegacyMsg()
endif
"XXX: end

" If user doesn't set config_Formatter in
" .vimrc then look up it in .editorconfig
if empty(g:config_Formatter)
  call FormatterApplyConfig(g:editorconfig_Formatter)
endif
