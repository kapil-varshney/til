---
title: "Efficiently Checking if a Number Has Two Consecutive Bits Set"
date: 2018-08-27T15:37:37+05:30
tags: ["golang"]
---

Last week someone I mentor asked for help with a programming challenge that
involved some bit twiddling. The first part of the problem was

> A number is known as special bit number if its binary representation contains atleast two
> consecutive 1's or set bits. For example 7 wih binary representation `111` is a special
> bit number. Similarly 3 (`11`) is also a special bit number.

The naive implementation was quite simple but got me thinking if there were better options.

## 1. Right Shift and Counter

This is the most straightforward approach where we check the least significant
bit (LSB) and increment a counter if it is `1`. As soon as the counter hits `1`
we exit or reset to `0` if the bit is not set.

```golang
func isSpecial(n uint32) bool {
	for wasLastBitOne := false; n > 0; n = n >> 1 {
		isCurrentBitOne := n%2 == 1
		if isCurrentBitOne && wasLastBitOne {
			return true
		}
		wasLastBitOne = isCurrentBitOne
	}

	return false
}
```

Now let's write a quick benchmark to see how it performs.

```golang
func BenchmarkIsSpecial(b *testing.B) {
	for n := 0; n < b.N; n++ {
		isSpecial(uint32(n))
	}
}
```

And the results are: you can perform about a 100 million of these per second.

```bash
> go test -bench 'BenchmarkIsSpecial$'
goos: darwin
goarch: amd64
pkg: github.com/zqureshi/special
BenchmarkIsSpecial-8    200000000          9.46 ns/op
PASS
ok    github.com/zqureshi/special 2.861s
```

## 2. Speedup via Lookup Table

We are working with 32-bit unsigned integers and notice that checking an 8-bit
long subsequence is no different than checking the whole number. For an 8-bit
sequence we have 256 (_2**8_) possible combinations and can precompute a lookup
table of all possible results.

```golang
var lookupTable = [256]bool{}

func init() {
	fmt.Println("Recomputing lookup table...")
	for i := uint32(0); i < 256; i++ {
		lookupTable[i] = isSpecial(i)
	}
}

func isSpecialLookup(n uint32) bool {
	if lookupTable[3] == false {
		panic("Lookup table not initialized!")
	}

	return lookupTable[uint8(n)] ||
		lookupTable[uint8(n>>7)] ||
		lookupTable[uint8(n>>14)] ||
		lookupTable[uint8(n>>21)] ||
		lookupTable[uint8(n>>24)]
}
```

An interesting thing to note here is that we cannot just check four bit ranges
`0-7, 8-15, 16-23, 28-31` because we will miss numbers that have consecutive
bits on the boundary i.e. bit 7 and 8, therefore we must always check
overlapping ranges `0-7, 7-14, 14-21, 21-28, 24-31`. In the last comparison of
bits `24-31` we re-check bits `24-28` but it is easier to just do so than special
case it and add extra logic.

And now let's also benchmark this.

```golang
func BenchmarkIsSpecialLookup(b *testing.B) {
	for n := 0; n < b.N; n++ {
		isSpecialLookup(uint32(n))
	}
}
```

```bash
> go test -bench '.'
Recomputing lookup table...
goos: darwin
goarch: amd64
pkg: github.com/zqureshi/special
BenchmarkIsSpecial-8          200000000          9.85 ns/op
BenchmarkIsSpecialLookup-8    1000000000         2.60 ns/op
PASS
ok    github.com/zqureshi/special 5.817s
```

We get an almost *4x* speedup using this approach as we are doing lesser
comparisons and memory writes but also due to the fact that the whole lookup
table fits in 32 bytes of memory which sits cosily in a 64 byte
[cache line](https://lwn.net/Articles/252125/).

## 3. Larger Lookup Table

We could extend the previous approach and precompute 65536 (_2**16_) values which would
allow us to cover the whole number in just 3 comparisons `0-15, 15-30, 16-31`.

```golang
func isSpecialLookup16(n uint32) bool {
	if lookupTable[3] == false {
		panic("Lookup table not initialized!")
	}

	return lookupTable[uint16(n)] ||
		lookupTable[uint16(n>>15)] ||
		lookupTable[uint16(n>>16)]
}
```

And benchmark

```golang
func BenchmarkIsSpecialLookup16(b *testing.B) {
	for n := 0; n < b.N; n++ {
		isSpecialLookup16(uint32(n))
	}
}
```

```bash
Recomputing lookup table...
goos: darwin
goarch: amd64
pkg: github.com/zqureshi/special
BenchmarkIsSpecial-8            200000000          9.57 ns/op
BenchmarkIsSpecialLookup-8      1000000000         2.62 ns/op
BenchmarkIsSpecialLookup16-8    1000000000         2.31 ns/op
PASS
ok    github.com/zqureshi/special 8.325s
```

A *12%* improvement in runtime but a *256x* blowup in table size (32 bytes vs
8192 bytes). While this performs better in this synthetic benchmark it might
not perform as well in production because of cache line and page misses.

## 4. Finding Something Better

At this point I was quite happy with the progress but was wondering if there was some intrinsic property of numbers that could be exploited to make this even faster. I landed upon this HackerRank [post](https://www.hackerrank.com/challenges/linkedin-practice-binary-numbers/forum) and a collection of [bit twiddling hacks](https://graphics.stanford.edu/~seander/bithacks.html#CountBitsSetKernighan) from Stanford's graphics department.

The solution was quite ingenious, if you take any binary number it will have
runs of set bits followed by one or more unset bits. Now if you left shift the
number, you move the `0` left and now if you bitwise and it with the original
number you have effectively cleared one set bit from a run. If you repeat this
process you will clear another bit, and another until the number is 0.

A worked out example will demonstrate this better.

```
14      =   1110
14 << 1 =  11100
a & b   =  01100

12      =   1100
12 << 1 =  11000
a & b   =  01000

8       =   1000
8  << 1 =  10000
a & b   =  00000
```

We can then simplify this algorithm to derive that if a number has at least two
consecutive bits set, then left shift followed by bitwise and will result in a
non-zero value. Let's work through this.

```
12      =   1100
12 << 1 =  11000
a & b   =  01000

10      =   1010
10 << 1 =  10100
a & b   =  00000
```

So now the code simply becomes

```golang
func isSpecialLeftShift(n uint32) bool {
	return (n & (n << 1)) > 0
}
```

and benchmark

```golang
func BenchmarkIsSpecialLeftShift(b *testing.B) {
	for n := 0; n < b.N; n++ {
		isSpecialLeftShift(uint32(n))
	}
}
```

```bash
Recomputing lookup table...
goos: darwin
goarch: amd64
pkg: github.com/zqureshi/special
BenchmarkIsSpecial-8              200000000          9.55 ns/op
BenchmarkIsSpecialLookup-8        1000000000         2.60 ns/op
BenchmarkIsSpecialLookup16-8      1000000000         2.32 ns/op
BenchmarkIsSpecialLeftShift-8     2000000000         0.27 ns/op
PASS
ok    github.com/zqureshi/special 8.871s
```

This is a *35x* improvement over our naive approach and only involves 3 instructions, which means it is also a candidate for inlining.

## 5. Epilogue

One thing that we didn't talk about was how did I verify that my implementations were correct? I implemented the naive version and manually tested it on various inputs. Then for every other implementation I iterated through the first billion integers and reconciled the optimized against the naive.

```golang
func main() {
	for n := uint32(0); n < 1000000000; n++ {
		result := isSpecial(n)
		if isSpecialLookup(n) != result {
			fmt.Printf("Error: %v == %b isSpecial: %v, isSpecialLookup: %v\n", n, n, result, isSpecialLookup(n))
			break
		}
		if isSpecialLookup16(n) != result {
			fmt.Printf("Error: %v == %b isSpecial: %v, isSpecialLookup16: %v\n", n, n, result, isSpecialLookup16(n))
			break
		}
		if isSpecialLeftShift(n) != result {
			fmt.Printf("Error: %v == %b isSpecial: %v, isSpecialLeftShift: %v\n", n, n, result, isSpecialLeftShift(n))
			break
		}
	}
}
```

<!--more-->
