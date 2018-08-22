---
title: "Platform Specific Go"
date: 2018-08-17T15:25:43+05:30
tags: ["golang", "codereading"]
---

You can compile platform specific go code by putting it in specially named files. If your component is called `foo.go` then putting something in `foo_darwin.go` will only compile that on Mac and `foo_linux` will do it on linux distros accordingly.

I recently encountered this while reading through Shopify's [sysv_mq](https://github.com/Shopify/sysv_mq/blob/master/wrapper.go#L154) implementation. This library is a wrapper around native syscalls via cgo.

The `ipcStat()` method in `wrapper.go` pulls out all the queue metadata from the native struct

```golang
// wrapper.go
stat := &QueueStats{
	Perm:  perm,
	Stime: int64(info.msg_stime),
	// Rtime:  int64(info.msg_rtime), // https://github.com/Shopify/sysv_mq/issues/10
	Ctime:  int64(info.msg_ctime),
	Cbytes: cbytesFromStruct(info),
	Qnum:   uint64(info.msg_qnum),
	Qbytes: uint64(info.msg_qbytes),
	Lspid:  int32(info.msg_lspid),
	Lrpid:  int32(info.msg_lrpid),
}
```

But it turns out that the `Cbytes` value is not in the same field across platforms, so instead of putting the fetching logic inline it is moved into a method `cbytesFromStruct()`.

On Mac the value is fetched from `msg_cbytes`

```golang
// wrapper_darwin.go
func cbytesFromStruct(info *_Ctype_struct___msqid_ds_new) uint64 {
	return uint64(info.msg_cbytes)
}
```

whereas on linux it is available in `__msg_cbytes`

```golang
// wrapper_linux.go
func cbytesFromStruct(info *_Ctype_struct_msqid_ds) uint64 {
	return uint64(info.__msg_cbytes)
}
```

Now `go build` will only compile the specific version of `cbytesFromStruct()` based on the target platform. One thing to note here is that if you are building static binaries from your Mac to run on a \*nix machine or container you'll probably want to build it inside a container to force the correct version.

<!--more-->
