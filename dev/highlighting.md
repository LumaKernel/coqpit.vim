# Hilighting


This file shows how this plugin highlight the coq code.



- `(highlight as done)`
- `<highlight as queued>`
- `[cursor]`

- Annotation means asking the coqtop to annotate the coq code by using command `Annotate`
  - This is useful to know when the next sentence ends
  - It is difficult for plugin makers to know this in some situations discussed below
    - This is why we use CoqTop as _strict syntax analyzer_
      while we use weak analyzer written in vim script for cursor jump

## Coq Next


```coq
<(Variable A: Type.)>
Goal A.

(* coq-next *)

<(Variable A: Type.)
Goal A.>
```


Think the situation that the below is defined.

```coq
Variable A : Type.
Variable f : A -> A.
Notation "{ a ." := (f a) (at level 50).
Goal A.
```


```coq

<(...)>
[r]efine ({_.).


(* coq-next *)

<(...)
refine ({_[.]>).

(* - cursor is moved once *)


(* after annotation *)

<(...)
refine ({_[.]).>

(* - highligh is moved, but cursor is not moved *)
(* - the reason for this behavior is showed below *)

```


```coq

<(...)>
[r]efine ({_.).
refine ({_.).


(* coq-next *)

<(...)
refine ({_[.]>).
refine ({_.).

(* coq-next *)

<(...)
refine ({_.)[.]>
refine ({_.).

(* coq-next *)

<(...)
refine ({_.).
refine ({_[.]>).

(* after annotation *)

<(...)
refine ({_.).
refine ({_[.]>).

(* - nothing was happened *)


(* after done *)

<(...
refine ({_.).)
refine ({_[.]>).


(* after annotation *)

<(...
refine ({_.).)
refine ({_[.]).>

(* - if we move cursor at this time,
  the user experiences suddenly (, asynchronously, or after very long time) cursor jumping *)


(* after done *)

<(...
refine ({_.).
refine ({_[.]).)>

```


### Consequently,

- Cursor jumping is happened only right after the user do `:CoqNext` ( __synchronous__ )
- `:CoqNext` does...
  1. Cussor jumping
  2. Mark next __expected__ sentence end as the position that shouled be exceeded or landed by CoqTop
    - This is like `:CoqToCursor` with ceiling



## Coq To Cursor

```coq
<Variable A: Type.>
Go[a]l A.

(* coq-to-cursor ceil *)

<Variable A: Type.
Go[a]>l A.
```


### Consequently,


- Cursor jumping is not happened after `:CoqToCursor`
- `:CoqToCursor` does...
  1. Mark the cursor position as the position that shouled be
    - landed or exceeded next time by CoqTop ( flooring )
    - exceeded or landed by CoqTop ( ceiling )
- Flooring method is calculated when the command was done
- And method is stored with cursor potision as `queued` ( like as paired boolean variable `s:is_flooring` )

