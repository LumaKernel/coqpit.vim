" this file is for all vim versions
try
	so ./test.vim
catch /.*/
	echoerr 'Unexpected Error happened!'
	echoerr v:exception
	echoerr 'from ' . v:throwpoint
	cq!
endtry
