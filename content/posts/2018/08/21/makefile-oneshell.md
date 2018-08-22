---
title: "Makefile .ONESHELL"
date: 2018-08-21T16:44:39+05:30
tags: ["make", "build"]
---

Suppose you wanted to take user input in your Makefile and then use it in subsequent commands you might try

```Makefile
newfile:
  @printf "Filename: "
  @read FILE
  touch $$FILE
```

This would not work because each command in that recipe is run in a separate shell. You'd have to cram it all in one line

```Makefile
newfile:
  @printf "Filename: " && read FILE && touch $$FILE
```

This works but is not super readable, fortunately `make` provides a phony target [`.ONESHELL`](https://www.gnu.org/software/make/manual/html_node/One-Shell.html) which basically lets you write a full script inline in the recipe. The full contents of the recipe are passed to a single shell to be executed so you might write

```Makefile
.ONESHELL:
newfile:
  @printf "Filename: "
  @read FILE
  touch $$FILE
```

This would be almost correct except for the fact that the second `@` would be passed verbatim to your shell, therefore with `.ONESHELL` only the first character is checked to see if it is special. So your final recipe looks like

```Makefile
.ONESHELL:
newfile:
  @printf "Filename: "
  read FILE
  touch $$FILE
```

**Note:** The default `make` command that ships with MacOS does not support `.ONESHELL` just yet, I had to `brew install make` and then invoke it via `gmake` to get things to work.
<!--more-->
