" Override syntax autoload to prevent system syntax loading

function! syntax#Enable()
  " Do nothing - prevent syntax enabling
endfunction

function! syntax#Disable()
  " Do nothing - syntax already disabled
endfunction

function! syntax#SynID(line, col, ...)
  " Return 0 to indicate no syntax
  return 0
endfunction

function! syntax#SynIDattr(synid, what, ...)
  " Return empty string for any syntax attributes
  return ""
endfunction

function! syntax#SynIDtrans(synid)
  " Return 0 for syntax translation
  return 0
endfunction