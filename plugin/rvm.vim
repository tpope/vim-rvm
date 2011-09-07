" rvm.vim - Switch Ruby versions from inside Vim
" Maintainer:   Tim Pope <http://tpo.pe/>

if exists('g:loaded_rvm') || v:version < 700 || &cp
  finish
endif

if !exists('$rvm_path') && isdirectory(expand('~/.rvm'))
  let $rvm_path = expand('~/.rvm')
  let $PATH .= ':' . $rvm_path . '/bin'
endif

if !exists('$rvm_path')
  finish
endif

let g:loaded_rvm = 1

" Utility {{{1

function! s:shellesc(arg) abort
  if a:arg =~ '^[A-Za-z0-9_/.-]\+$'
    return a:arg
  else
    return shellescape(a:arg)
  endif
endfunction

" }}}1
" :Rvm {{{1

function! rvm#buffer_path_identifier(...)
  let name = bufname(a:0 ? a:1 : '%')
  if name ==# ''
    let path = '.'
  elseif isdirectory(name)
    let path = name
  else
    let path = fnamemodify(name, ':h')
  endif
  return system('rvm tools path-identifier '.s:shellesc(path))
endfunction

function! s:Rvm(bang,...) abort
  let path = split($PATH,':')
  call filter(path, 'v:val[0:strlen($rvm_path)] !=# $rvm_path."/"')

  if a:0 && a:0 < 3 && a:1 ==# 'use'
    let use = 1
    let args = a:000[1:-1]
  else
    let use = 0
    let args = copy(a:000)
  endif

  if len(args) > 1 || (len(args) == 1 && args[0] !~ '^\%(@\|\d\|default\|j\=ruby\|goruby\|rbx\|ree\|kiji\|maglev\|ironruby\|system\)' && !use)
    return '!rvm '.join(map(copy(a:000), 's:shellesc(v:val)'), ' ')
  elseif !empty(args) && args[-1] ==# 'system'
    let $RUBY_VERSION = ''
    let $MY_RUBY_HOME = ''
    let $IRBRC = expand('~/.irbrc')
    let $PATH = join(path + [$rvm_path.'/bin'],':')
    let $GEM_HOME = system('env -i PATH="'.$PATH.'" ruby -rubygems -e "print Gem.dir"')
    let $GEM_PATH = system('env -i PATH="'.$PATH.'" ruby -rubygems -e "print Gem.path.join(%{:})"')
    if use
      return 'echomsg "Using system ruby"'
    else
      return ''
    endif
  elseif !empty(args)
    let desired = system('rvm tools strings '.s:shellesc(args[0]))[0:-2]
  elseif use || !exists('b:rvm_string')
    let desired = rvm#buffer_path_identifier()
  else
    let desired = b:rvm_string
  endif

  let ver = matchstr(desired,'[^@]*')
  let gemset = matchstr(desired,'@.*')
  if ver ==# ''
    return 'echoerr "Ruby version not found"'
  endif
  if !isdirectory($rvm_path . '/rubies/' . ver)
    if $rvm_install_on_use_flag
      execute 'Rvm install '.ver
    else
      return 'echoerr "Ruby version not installed: :Rvm install ".'.string(ver)
    endif
  endif
  let b:rvm_string = desired

  let $RUBY_VERSION = ver
  let $GEM_HOME = $rvm_path . '/gems/' . $RUBY_VERSION . gemset
  let $MY_RUBY_HOME = $rvm_path . '/rubies/' . $RUBY_VERSION
  let $IRBRC = $MY_RUBY_HOME . '/.irbrc'

  let gemsets = [$GEM_HOME, $rvm_path . '/gems/' . $RUBY_VERSION . '@global']

  let $GEM_PATH = join(gemsets, ':')
  let $PATH = join(
        \ [$MY_RUBY_HOME.'/bin'] +
        \ map(gemsets,'v:val."/bin"') +
        \ [$rvm_path.'/bin'] +
        \ path, ':')
  if use
    return 'echomsg "Using " . $GEM_HOME'
  else
    return ''
  endif
endfunction

function! s:Complete(A,L,P)
  if a:A =~# '@'
    let requested = matchstr(a:A,'^[^@]*')
    let desired = system('rvm tools strings '.s:shellesc(requested))[0:-2]
    let all = split(glob($rvm_path.'/gems/'.desired.'@*'),"\n")
    call map(all,"v:val[strlen($rvm_path)+6:-1]")
    call map(all,'substitute(v:val,"^[^@]*",requested,"")')
  else
    let all = split(glob($rvm_path.'/rubies/*'),"\n")
    call map(all,"v:val[strlen($rvm_path)+8:-1]")
    if a:A !~# '^r'
      call map(all,'substitute(v:val,"^ruby-\\ze\\d","","")')
    endif
  endif
  return join(all,"\n")
endfunction

command! -bar -nargs=* -complete=custom,s:Complete Rvm :execute s:Rvm(<bang>0,<f-args>)

" }}}1
" Statusline {{{1

function! rvm#string()
  return matchstr($GEM_HOME,'[^/]*$')
endfunction

function! rvm#statusline()
  return substitute('['.rvm#string().']','^\[\]$','','')
endfunction

function! rvm#statusline_ft_ruby()
  if &filetype ==# 'ruby'
    return rvm#statusline()
  else
    return ''
  endif
endfunction

" }}}1

" vim:set sw=2 sts=2:
