---
title: "Abbreviations in Vim"
date: 2018-08-24T11:52:13+05:30
tags: ["vim"]
---

Vim has a nifty feature that allows you to define keywords that will then expand to a configurable string. The basic syntax is

```vim
:iabbrev {kw} {expansion}
```

I am going to define two abbreviations `__w` and `__t` that will expand to my personal homepage and to this journal respectively

```vim
:iabbrev __w http://zqureshi.in
:iabbrev __t https://til.zqureshi.in
```

Now when I'm in *insert* mode and type `__w` followed by a `<Space>` the expansion will be triggered. In the situation that you do not want the expansion you would type `__w` and then press `<Ctrl-V>` followed by any other character to insert it verbatim. Usually I'll do `<Ctrl-V><Space>`.

<!--more-->
