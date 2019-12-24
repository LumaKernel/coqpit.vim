Variable A : Type.
Variable f : A -> A.

Section sec1.
  Notation " { a . ) ." := (f a).

  Goal A.
    refine ( { _ . ) . ).
    all: refine ( { _ . ). ).
    refine ?[ふが].
    [ふが]: refine ( { _ . ). ).
    Admitted.
End sec1.

Section sec2.
  Notation " { . a .) ." := (f a).

  Goal A.
    refine ( {. _ .) . ).
    all: refine ( {. _ .). ).
    refine ?[a].
    [a]: { refine ( {. _ .) . ). }
    Undo.
    1: refine ( {. _ .). ).
    Admitted.
End sec2.

Section sec3.
  Notation " ({ . a } ." := (f a).

  Goal A.
    refine ( ({ . _ } . ).
    refine ?[a].
    [a]:refine ( ({ . _ } . ).
    1:{refine ( ({ . _ } . ). }
    Admitted.
End sec3.

Section sec4.
  Notation "'Admitted' . a" := (f a) (at level 20).
  Notation "'_' a" := (f a) (at level 20).

  Goal A.
    refine ( _ _ ).
    refine ?[a].
    [a]:refine ( Admitted . _ ).
    1:{refine ( Admitted . _ ).
    Admitted.
End sec4. 


  (* Notation "'""' a" := (f a) (at level 20). *)

