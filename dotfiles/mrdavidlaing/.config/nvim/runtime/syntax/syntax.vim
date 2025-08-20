" Override syntax.vim to prevent E1155 error
if exists("syntax_on")
  finish
endif
let syntax_on = 1
finish