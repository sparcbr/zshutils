#!/bin/zsh
{
	include android
} always {
	catch '*'
	echo ret=$renct
}
echo asda
include debug
debug -r vscode "$@"
