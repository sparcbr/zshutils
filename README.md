# zshutils
Useful functions using ZSH shell

## Examples:
### menu selection using chooser:
Selectable options are printed, and an arrow points to current selected option. 
Enter finishes and prints the selected options (or saves to a var with -v varname)
   chooser -n 7 -D delete create delete update ¬teste bla ble bli asdasd asd asd
explanation: -n 7: the 7th item is not selectable
-D delete: delete is the default item
items started by '¬' character means they're only non-selectable subsection headers

   chooser -v abc one two three
explanation: -v abc: saves to var abc the selected option

-H string, --header string: prints a header before everything
-F string, --footer string: prints a footer after everything

Options that further filter the selected option:
   -R: uses regexp to select a portion of the selected result
   -s sep -f number: uses separator and a number to print only that field

There is an option for multi-selection as well:
   --multi
   
And file selection:
   --file
   
Multiple files:
   --files
