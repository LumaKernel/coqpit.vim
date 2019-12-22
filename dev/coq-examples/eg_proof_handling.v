(* Proof handling *)
(* ref :
https://coq.inria.fr/refman/proof-engine/proof-handling.html?highlight=local%20variables
*)

Goal True. trivial. Qed.

Goal True. trivial. Defined.

Compute Unnamed_thm.  (* Opaque  			*)
Compute Unnamed_thm0. (* Transparent  *)


Goal True. Admitted.  (* Defined as an axiom *)
Goal True. Abort.     (* Not defined *)

Set Nested Proofs Allowed.
(* Nested Proof *) (* deprecated! *)
Goal True.
  Goal True. (* Nested Proof *)
  trivial. Qed.

  (* Nested Proof Abort *)
  Theorem X:True. Abort.

  (* Nested Proof Abort Jump *)
  Theorem X:True. Theorem Y:True. Abort X.
  (* nasty example *)
  Theorem X:1=1. Theorem X:2=2. Abort X. Abort X.

  (* Nested Proof Abort Jump with All *)
  Theorem X: True. Abort All.

(* Goal x. ... [Qed/Defined/Save A].      *)
(* Thm A:x. ... [Qed/Defined].            *)
(* [Thm A:/Goal] x. ... [Abort/Admitted]. *)
(* Thm A:x. ... Abort A.                  *)
(* [Thm A:/Goal] x. ... Abort All.        *)

(* Proof :term: *)
Goal nat. Proof 1.

Section sec1.
  Variable x y: nat.
  Hypothesis H: x = 1.
  Hypothesis G: y = 1.

  (* Proof using :term:+ *)
  Goal x = 1. Proof using H. trivial. Qed.
  Goal x = 1. Proof using H x. trivial. Qed.
  
  (* Proof with *)
  (* ref : https://coq.inria.fr/refman/proof-engine/tactics.html#coq:cmd.proof-with *)
  Goal x = 1. Proof with trivial. idtac... Qed.
  
  (* Combine *)
  Goal x = 1. Proof using H with trivial. idtac... Qed.
  Goal x = 1. Proof with trivial using H. idtac... Qed.
  
  (* nasty; using twice *)
  Goal x = 1. Proof using H with trivial using H. idtac... Qed.
  
  (* not happen
    (* with twice *)
    Goal x = 1. Proof with trivial with auto. Abort.
    
    (* with using *)
    Goal x = 1. Proof with using. Abort.
    
    (* using with *)
    Goal x = 1. Proof using with. Abort.
  *)

  (* Proof using All *)
  Goal x = 1. Proof using All. trivial. Qed.
  (* not happen
    (* using All and another using *)
    Goal x = 1. Proof using All using x. trivial. Qed.
    Goal x = 1. Proof using All using -(x). trivial. Qed.
    Goal x = 1. Proof using All using All. trivial. Qed.
  *)
  
  (* Proof using Type* *)
  Goal x = 1. Proof using x*. trivial. Qed.
  Goal x = 1. Proof using Type*. trivial. Qed.
  
  (* not happen
    (* using Type* and another using *)
    Goal x = 1. Proof using x* using x*. trivial. Qed.
    Goal x = 1. Proof using x using x*. trivial. Qed.
    Goal x = 1. Proof using x* using x. trivial. Qed.
  *)
  
  (* Proof using -(:ident:+) *)
  Goal x = x. Proof using -H. trivial. Qed.
  Goal x = x. Proof using -(H). trivial. Qed.
  Goal x = x. Proof using -(H H). trivial. Qed.

  (* Proof using collection with collection-operations *)
  Collection Hs := H H H .
  Collection xs := x.
  Goal x = x. Proof using Hs. trivial. Qed.
  Goal x = x. Proof using Hs + Hs. trivial. Qed.
  Goal x = x. Proof using -(Hs). trivial. Qed.
  Goal x = x. Proof using Hs-Hs. trivial. Qed.
  Goal x = x. Proof using Hs-H. trivial. Qed.
  Goal x = 1. Proof using xs*. trivial. Qed.
  
  Set Default Proof Using "H".
  Goal x = 1. Proof. trivial. Qed.
  
  Unset Default Proof Using.
  Set Suggest Proof Using.
  Goal x = 1. Proof. trivial. Qed. (* suggested *)
  
  Set Default Proof Using "H".
  Goal x = 1. Proof. trivial. Qed. (* not suggested *)
  Goal x = 1. trivial. Qed. (* suggested *)
End sec1.

(* NOTE : Between Undo, Restart and another, there may be a little bit difference, but can't distinguish them clearly. *)
Goal exists a:nat, a=a.
  eexists _. trivial.
  Undo.     (* Proof Command *)
  Restart.  (* Proof Command *)
  eexists _.
  trivial.
  Show Existentials. (* Proof Command *)

  Unshelve. (* Proof Command *) (* ref : https://coq.inria.fr/refman/proof-engine/tactics.html?highlight=unshelve#coq:cmd.unshelve *)
  exact 1.
  Undo 2.

  Existential 1 := 1. (* Proof Command *)
  Undo.

  Grab Existential Variables. (* Proof Command *)
  exact 1.

  Restart.
  exists 1. trivial.
Save Named.

Section sec2.
  Variable P : nat -> Prop. Check P.
  Hypothesis H: forall x , P x.
  (* Braces with Focus *) (* deprecated! *)
  Goal P 1 /\ P 2 /\ P 3.
    repeat split.
    
    (* Focus, Unfocus, Unfocused *)
    Focus 2. { trivial. (* not Unfocused *) } Unfocus. Unfocused.
    2: { auto. }
    auto.
  Qed.

  (* Braces *)
  Goal P 1 /\ P 2 /\ P 3.
    repeat split.
    { auto. }     (* no number *)
    2: { auto. }  (* with number *)
    refine ?[a].  (* name it "a" *)
    [a]:{ auto. } (* with name *)
  Qed.
  
  Ltac name_goal name := refine ?[name].
  
  Goal forall n, n + 0 = n.
    Proof.
    induction n; [ name_goal base | name_goal step ].
    [base]: {
      reflexivity.
    }
    [step]: {
      simpl. f_equal. assumption.
    }
  Qed.
  
  Goal exists n : nat, n = n.
    eexists ?[xあうｗ''].
    
    assert True. {
      trivial.
    }
    
    reflexivity.
    [xあうｗ'']: exact 0.
    (* [x]: { exact 0. } *)
  Qed.
  
  (* Bullets *)
  Goal ((P 1 /\ P 2) /\ P 3) /\ P 4.
    split.
    - split.
      + split.
        ++ trivial.
        ++ trivial.
      + trivial.
    - trivial.
  Qed.
  
  Set Bullet Behavior "None".
  Set Bullet Behavior "Strict Subproofs".


  (* Requesting information *)

  (* Bullets *)
  Goal (exists n, n = 0) /\ P 2 /\ P 3.
    repeat split.
    Show.
    Show 1.
    Show 2.
    eexists ?[n].
    Show n.
    Show Script. (* deprecated! *)
    Show Proof.
    Show Conjectures.
  Admitted.
  Goal P 1 -> P 2 -> P 3 -> P 4.
    Show Intro.
    Show Intros.
    intro.
    Show Intro.
    Show Intros.
    
    Undo.
    Show Existentials.
    
  Admitted.
  
  Goal forall x y z: nat, x+y+z=y+z+x.
    intros.
    Show Universes. (* TODO : what ? *)
    
    Show Match nat.
  Admitted.
End sec2.

(* Set Diffs "on" | "off" | "removed" *)
(* TODO : How should we treat this in Coquille ? *)

Set Hyps Limit 2.
Set Nested Proofs Allowed.
Optimize Proof.
Optimize Heap.
Goal True.
  Optimize Proof.
  Optimize Heap.
  trivial.
Qed.
