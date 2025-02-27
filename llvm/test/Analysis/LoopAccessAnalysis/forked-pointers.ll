; RUN: opt -disable-output -passes='print-access-info' %s 2>&1 | FileCheck %s
; RUN: opt -disable-output -passes='print-access-info' -max-forked-scev-depth=2 %s 2>&1 | FileCheck -check-prefix=RECURSE %s

target datalayout = "e-m:e-i8:8:32-i16:16:32-i64:64-i128:128-n32:64-S128"

; CHECK-LABEL: function 'forked_ptrs_simple':
; CHECK-NEXT:  loop:
; CHECK-NEXT:    Memory dependences are safe with run-time checks
; CHECK-NEXT:    Dependences:
; CHECK-NEXT:    Run-time memory checks:
; CHECK-NEXT:    Check 0:
; CHECK-NEXT:      Comparing group ([[G1:.+]]):
; CHECK-NEXT:        %gep.Dest = getelementptr inbounds float, ptr %Dest, i64 %iv
; CHECK-NEXT:        %gep.Dest = getelementptr inbounds float, ptr %Dest, i64 %iv
; CHECK-NEXT:      Against group ([[G2:.+]]):
; CHECK-NEXT:        %select = select i1 %cmp, ptr %gep.1, ptr %gep.2
; CHECK-NEXT:    Check 1:
; CHECK-NEXT:      Comparing group ([[G1]]):
; CHECK-NEXT:        %gep.Dest = getelementptr inbounds float, ptr %Dest, i64 %iv
; CHECK-NEXT:        %gep.Dest = getelementptr inbounds float, ptr %Dest, i64 %iv
; CHECK-NEXT:      Against group ([[G3:.+]]):
; CHECK-NEXT:        %select = select i1 %cmp, ptr %gep.1, ptr %gep.2
; CHECK-NEXT:    Grouped accesses:
; CHECK-NEXT:      Group [[G1]]
; CHECK-NEXT:        (Low: %Dest High: (400 + %Dest))
; CHECK-NEXT:          Member: {%Dest,+,4}<nuw><%loop>
; CHECK-NEXT:          Member: {%Dest,+,4}<nuw><%loop>
; CHECK-NEXT:      Group [[G2]]:
; CHECK-NEXT:        (Low: %Base1 High: (400 + %Base1))
; CHECK-NEXT:          Member: {%Base1,+,4}<nw><%loop>
; CHECK-NEXT:      Group [[G3]]:
; CHECK-NEXT:        (Low: %Base2 High: (400 + %Base2))
; CHECK-NEXT:          Member: {%Base2,+,4}<nw><%loop>
; CHECK-EMPTY:
; CHECK-NEXT:    Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:    SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:    Expressions re-written:

define void @forked_ptrs_simple(ptr nocapture readonly %Base1, ptr nocapture readonly %Base2, ptr %Dest) {
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %gep.Dest = getelementptr inbounds float, ptr %Dest, i64 %iv
  %l.Dest = load float, ptr %gep.Dest
  %cmp = fcmp une float %l.Dest, 0.0
  %gep.1 = getelementptr inbounds float, ptr %Base1, i64 %iv
  %gep.2 = getelementptr inbounds float, ptr %Base2, i64 %iv
  %select = select i1 %cmp, ptr %gep.1, ptr %gep.2
  %sink = load float, ptr %select, align 4
  store float %sink, ptr %gep.Dest, align 4
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond.not = icmp eq i64 %iv.next, 100
  br i1 %exitcond.not, label %exit, label %loop

exit:
  ret void
}

; CHECK-LABEL: function 'forked_ptrs_different_base_same_offset':
; CHECK-NEXT:  for.body:
; CHECK-NEXT:    Memory dependences are safe with run-time checks
; CHECK-NEXT:    Dependences:
; CHECK-NEXT:    Run-time memory checks:
; CHECK-NEXT:    Check 0:
; CHECK-NEXT:      Comparing group ([[G1:.+]]):
; CHECK-NEXT:        %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
; CHECK-NEXT:      Against group ([[G2:.+]]):
; CHECK-NEXT:        %arrayidx = getelementptr inbounds i32, ptr %Preds, i64 %indvars.iv
; CHECK-NEXT:    Check 1:
; CHECK-NEXT:      Comparing group ([[G1]]):
; CHECK-NEXT:        %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
; CHECK-NEXT:      Against group ([[G3:.+]]):
; CHECK-NEXT:        %.sink.in = getelementptr inbounds float, ptr %spec.select, i64 %indvars.iv
; CHECK-NEXT:    Check 2:
; CHECK-NEXT:      Comparing group ([[G1]]):
; CHECK-NEXT:        %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
; CHECK-NEXT:      Against group ([[G4:.+]]):
; CHECK-NEXT:        %.sink.in = getelementptr inbounds float, ptr %spec.select, i64 %indvars.iv
; CHECK-NEXT:    Grouped accesses:
; CHECK-NEXT:      Group [[G1]]:
; CHECK-NEXT:        (Low: %Dest High: (400 + %Dest))
; CHECK-NEXT:          Member: {%Dest,+,4}<nuw><%for.body>
; CHECK-NEXT:      Group [[G2]]:
; CHECK-NEXT:        (Low: %Preds High: (400 + %Preds))
; CHECK-NEXT:          Member: {%Preds,+,4}<nuw><%for.body>
; CHECK-NEXT:      Group [[G3]]:
; CHECK-NEXT:        (Low: %Base2 High: (400 + %Base2))
; CHECK-NEXT:          Member: {%Base2,+,4}<nw><%for.body>
; CHECK-NEXT:      Group [[G4]]:
; CHECK-NEXT:        (Low: %Base1 High: (400 + %Base1))
; CHECK-NEXT:          Member: {%Base1,+,4}<nw><%for.body>
; CHECK-EMPTY:
; CHECK-NEXT:   Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:   SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:   Expressions re-written:

;; We have a limit on the recursion depth for finding a loop invariant or
;; addrec term; confirm we won't exceed that depth by forcing a lower
;; limit via -max-forked-scev-depth=2
; RECURSE-LABEL: Loop access info in function 'forked_ptrs_same_base_different_offset':
; RECURSE-NEXT:   for.body:
; RECURSE-NEXT:     Report: cannot identify array bounds
; RECURSE-NEXT:     Dependences:
; RECURSE-NEXT:     Run-time memory checks:
; RECURSE-NEXT:     Grouped accesses:
; RECURSE-EMPTY:
; RECURSE-NEXT:     Non vectorizable stores to invariant address were not found in loop.
; RECURSE-NEXT:     SCEV assumptions:
; RECURSE-EMPTY:
; RECURSE-NEXT:     Expressions re-written:

;;;; Derived from the following C code
;; void forked_ptrs_different_base_same_offset(float *A, float *B, float *C, int *D) {
;;   for (int i=0; i<100; i++) {
;;     if (D[i] != 0) {
;;       C[i] = A[i];
;;     } else {
;;       C[i] = B[i];
;;     }
;;   }
;; }

define dso_local void @forked_ptrs_different_base_same_offset(ptr nocapture readonly nonnull %Base1, ptr nocapture readonly %Base2, ptr nocapture %Dest, ptr nocapture readonly %Preds) {
entry:
  br label %for.body

for.cond.cleanup:
  ret void

for.body:
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %Preds, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1.not = icmp eq i32 %0, 0
  %spec.select = select i1 %cmp1.not, ptr %Base2, ptr %Base1
  %.sink.in = getelementptr inbounds float, ptr %spec.select, i64 %indvars.iv
  %.sink = load float, ptr %.sink.in, align 4
  %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
  store float %.sink, ptr %1, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, 100
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; CHECK-LABEL: function 'forked_ptrs_different_base_same_offset_possible_poison':
; CHECK-NEXT:  for.body:
; CHECK-NEXT:    Memory dependences are safe with run-time checks
; CHECK-NEXT:    Dependences:
; CHECK-NEXT:    Run-time memory checks:
; CHECK-NEXT:    Check 0:
; CHECK-NEXT:      Comparing group ([[G1:.+]]):
; CHECK-NEXT:        %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
; CHECK-NEXT:      Against group ([[G2:.+]]):
; CHECK-NEXT:        %arrayidx = getelementptr inbounds i32, ptr %Preds, i64 %indvars.iv
; CHECK-NEXT:    Check 1:
; CHECK-NEXT:      Comparing group ([[G1]]):
; CHECK-NEXT:        %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
; CHECK-NEXT:      Against group ([[G3:.+]]):
; CHECK-NEXT:        %.sink.in = getelementptr inbounds float, ptr %spec.select, i64 %indvars.iv
; CHECK-NEXT:    Check 2:
; CHECK-NEXT:      Comparing group ([[G1]]):
; CHECK-NEXT:        %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
; CHECK-NEXT:      Against group ([[G4:.+]]):
; CHECK-NEXT:        %.sink.in = getelementptr inbounds float, ptr %spec.select, i64 %indvars.iv
; CHECK-NEXT:    Grouped accesses:
; CHECK-NEXT:      Group [[G1]]:
; CHECK-NEXT:        (Low: %Dest High: (400 + %Dest))
; CHECK-NEXT:          Member: {%Dest,+,4}<nw><%for.body>
; CHECK-NEXT:      Group [[G2]]:
; CHECK-NEXT:        (Low: %Preds High: (400 + %Preds))
; CHECK-NEXT:          Member: {%Preds,+,4}<nuw><%for.body>
; CHECK-NEXT:      Group [[G3]]:
; CHECK-NEXT:        (Low: %Base2 High: (400 + %Base2))
; CHECK-NEXT:          Member: {%Base2,+,4}<nw><%for.body>
; CHECK-NEXT:      Group [[G4]]:
; CHECK-NEXT:        (Low: %Base1 High: (400 + %Base1))
; CHECK-NEXT:          Member: {%Base1,+,4}<nw><%for.body>
; CHECK-EMPTY:
; CHECK-NEXT:   Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:   SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:   Expressions re-written:

define dso_local void @forked_ptrs_different_base_same_offset_possible_poison(ptr nocapture readonly %Base1, ptr nocapture readonly %Base2, ptr nocapture %Dest, ptr nocapture readonly %Preds, i1 %c) {
entry:
  br label %for.body

for.cond.cleanup:
  ret void

for.body:
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %latch ]
  %arrayidx = getelementptr inbounds i32, ptr %Preds, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1.not = icmp eq i32 %0, 0
  %spec.select = select i1 %cmp1.not, ptr %Base2, ptr %Base1
  %.sink.in = getelementptr inbounds float, ptr %spec.select, i64 %indvars.iv
  %.sink = load float, ptr %.sink.in, align 4
  %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
  br i1 %c, label %then, label %latch

then:
  store float %.sink, ptr %1, align 4
  br label %latch

latch:
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, 100
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; CHECK-LABEL: function 'forked_ptrs_same_base_different_offset':
; CHECK-NEXT:   for.body:
; CHECK-NEXT:     Report: cannot identify array bounds
; CHECK-NEXT:     Dependences:
; CHECK-NEXT:     Run-time memory checks:
; CHECK-NEXT:     Grouped accesses:
; CHECK-EMPTY:
; CHECK-NEXT:     Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:     SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:     Expressions re-written:

;;;; Derived from the following C code
;; void forked_ptrs_same_base_different_offset(float *A, float *B, int *C) {
;;   int offset;
;;   for (int i = 0; i < 100; i++) {
;;     if (C[i] != 0)
;;       offset = i;
;;     else
;;       offset = i+1;
;;     B[i] = A[offset];
;;   }
;; }

define dso_local void @forked_ptrs_same_base_different_offset(ptr nocapture readonly %Base, ptr nocapture %Dest, ptr nocapture readonly %Preds) {
entry:
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body
  ret void

for.body:                                         ; preds = %entry, %for.body
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %i.014 = phi i32 [ 0, %entry ], [ %add, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %Preds, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1.not = icmp eq i32 %0, 0
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %add = add nuw nsw i32 %i.014, 1
  %1 = trunc i64 %indvars.iv to i32
  %offset.0 = select i1 %cmp1.not, i32 %add, i32 %1
  %idxprom213 = zext i32 %offset.0 to i64
  %arrayidx3 = getelementptr inbounds float, ptr %Base, i64 %idxprom213
  %2 = load float, ptr %arrayidx3, align 4
  %arrayidx5 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
  store float %2, ptr %arrayidx5, align 4
  %exitcond.not = icmp eq i64 %indvars.iv.next, 100
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

;;;; Cases that can be handled by a forked pointer but are not currently allowed.

; CHECK-LABEL: function 'forked_ptrs_uniform_and_strided_forks':
; CHECK-NEXT:  for.body:
; CHECK-NEXT:    Report: cannot identify array bounds
; CHECK-NEXT:    Dependences:
; CHECK-NEXT:    Run-time memory checks:
; CHECK-NEXT:    Grouped accesses:
; CHECK-EMPTY:
; CHECK-NEXT:    Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:    SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:    Expressions re-written:

;;;; Derived from forked_ptrs_same_base_different_offset with a manually
;;;; added uniform offset and a mul to provide a stride

define dso_local void @forked_ptrs_uniform_and_strided_forks(float* nocapture readonly %Base, float* nocapture %Dest, i32* nocapture readonly %Preds) {
entry:
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body
  ret void

for.body:                                         ; preds = %entry, %for.body
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %i.014 = phi i32 [ 0, %entry ], [ %add, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %Preds, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1.not = icmp eq i32 %0, 0
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %add = add nuw nsw i32 %i.014, 1
  %1 = trunc i64 %indvars.iv to i32
  %mul = mul i32 %1, 3
  %offset.0 = select i1 %cmp1.not, i32 4, i32 %mul
  %idxprom213 = sext i32 %offset.0 to i64
  %arrayidx3 = getelementptr inbounds float, ptr %Base, i64 %idxprom213
  %2 = load float, ptr %arrayidx3, align 4
  %arrayidx5 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
  store float %2, ptr %arrayidx5, align 4
  %exitcond.not = icmp eq i64 %indvars.iv.next, 100
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

; CHECK-LABEL:  function 'forked_ptrs_gather_and_contiguous_forks':
; CHECK-NEXT:   for.body:
; CHECK-NEXT:     Report: cannot identify array bounds
; CHECK-NEXT:     Dependences:
; CHECK-NEXT:     Run-time memory checks:
; CHECK-NEXT:     Grouped accesses:
; CHECK-EMPTY:
; CHECK-NEXT:     Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:     SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:     Expressions re-written:

;;;; Derived from forked_ptrs_same_base_different_offset with a gather
;;;; added using Preds as an index array in addition to the per-iteration
;;;; condition.

define dso_local void @forked_ptrs_gather_and_contiguous_forks(ptr nocapture readonly %Base1, ptr nocapture readonly %Base2, ptr nocapture %Dest, ptr nocapture readonly %Preds) {
entry:
  br label %for.body

for.cond.cleanup:                                 ; preds = %for.body
  ret void

for.body:                                         ; preds = %entry, %for.body
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %Preds, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1.not = icmp eq i32 %0, 0
  %arrayidx9 = getelementptr inbounds float, ptr %Base2, i64 %indvars.iv
  %idxprom4 = sext i32 %0 to i64
  %arrayidx5 = getelementptr inbounds float, ptr %Base1, i64 %idxprom4
  %.sink.in = select i1 %cmp1.not, ptr %arrayidx9, ptr %arrayidx5
  %.sink = load float, ptr %.sink.in, align 4
  %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
  store float %.sink, ptr %1, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, 100
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

;; We don't currently handle a fork in both the base and the offset of a
;; GEP instruction.

; CHECK-LABEL: Loop access info in function 'forked_ptrs_two_forks_gep':
; CHECK-NEXT:   for.body:
; CHECK-NEXT:     Report: cannot identify array bounds
; CHECK-NEXT:     Dependences:
; CHECK-NEXT:     Run-time memory checks:
; CHECK-NEXT:     Grouped accesses:
; CHECK-EMPTY:
; CHECK-NEXT:     Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:     SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:     Expressions re-written:

define dso_local void @forked_ptrs_two_forks_gep(ptr nocapture readonly %Base1, ptr nocapture readonly %Base2, ptr nocapture %Dest, ptr nocapture readonly %Preds) {
entry:
  br label %for.body

for.cond.cleanup:
  ret void

for.body:
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, i32* %Preds, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1.not = icmp eq i32 %0, 0
  %spec.select = select i1 %cmp1.not, ptr %Base2, ptr %Base1
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %offset = select i1 %cmp1.not, i64 %indvars.iv.next, i64 %indvars.iv
  %.sink.in = getelementptr inbounds float, ptr %spec.select, i64 %offset
  %.sink = load float, ptr %.sink.in, align 4
  %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
  store float %.sink, ptr %1, align 4
  %exitcond.not = icmp eq i64 %indvars.iv.next, 100
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body
}

;; We don't handle forks as children of a select

; CHECK-LABEL: Loop access info in function 'forked_ptrs_two_select':
; CHECK-NEXT:  loop:
; CHECK-NEXT:    Report: cannot identify array bounds
; CHECK-NEXT:    Dependences:
; CHECK-NEXT:    Run-time memory checks:
; CHECK-NEXT:    Grouped accesses:
; CHECK-EMPTY:
; CHECK-NEXT:    Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:    SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:    Expressions re-written:

define void @forked_ptrs_two_select(ptr nocapture readonly %Base1, ptr nocapture readonly %Base2, ptr nocapture readonly %Base3, ptr %Dest) {
entry:
  br label %loop

loop:
  %iv = phi i64 [ 0, %entry ], [ %iv.next, %loop ]
  %gep.Dest = getelementptr inbounds float, ptr %Dest, i64 %iv
  %l.Dest = load float, ptr %gep.Dest
  %cmp = fcmp une float %l.Dest, 0.0
  %cmp1 = fcmp une float %l.Dest, 1.0
  %gep.1 = getelementptr inbounds float, ptr %Base1, i64 %iv
  %gep.2 = getelementptr inbounds float, ptr %Base2, i64 %iv
  %gep.3 = getelementptr inbounds float, ptr %Base3, i64 %iv
  %select = select i1 %cmp, ptr %gep.1, ptr %gep.2
  %select1 = select i1 %cmp1, ptr %select, ptr %gep.3
  %sink = load float, ptr %select1, align 4
  store float %sink, ptr %gep.Dest, align 4
  %iv.next = add nuw nsw i64 %iv, 1
  %exitcond.not = icmp eq i64 %iv.next, 100
  br i1 %exitcond.not, label %exit, label %loop

exit:
  ret void
}

;; We don't yet handle geps with more than 2 operands
; CHECK-LABEL: Loop access info in function 'forked_ptrs_too_many_gep_ops':
; CHECK-NEXT:   for.body:
; CHECK-NEXT:     Report: cannot identify array bounds
; CHECK-NEXT:     Dependences:
; CHECK-NEXT:     Run-time memory checks:
; CHECK-NEXT:     Grouped accesses:
; CHECK-EMPTY:
; CHECK-NEXT:     Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:     SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:     Expressions re-written:

define void @forked_ptrs_too_many_gep_ops(ptr nocapture readonly %Base1, ptr nocapture readonly %Base2, ptr nocapture %Dest, ptr nocapture readonly %Preds) {
entry:
  br label %for.body

for.body:
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %Preds, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1.not = icmp eq i32 %0, 0
  %spec.select = select i1 %cmp1.not, ptr %Base2, ptr %Base1
  %.sink.in = getelementptr inbounds [1000 x float], ptr %spec.select, i64 0, i64 %indvars.iv
  %.sink = load float, ptr %.sink.in, align 4
  %1 = getelementptr inbounds float, ptr %Dest, i64 %indvars.iv
  store float %.sink, ptr %1, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  %exitcond.not = icmp eq i64 %indvars.iv.next, 100
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body

for.cond.cleanup:
  ret void
}

;; We don't currently handle vector GEPs
; CHECK-LABEL: Loop access info in function 'forked_ptrs_vector_gep':
; CHECK-NEXT:   for.body:
; CHECK-NEXT:     Report: cannot identify array bounds
; CHECK-NEXT:     Dependences:
; CHECK-NEXT:     Run-time memory checks:
; CHECK-NEXT:     Grouped accesses:
; CHECK-EMPTY:
; CHECK-NEXT:     Non vectorizable stores to invariant address were not found in loop.
; CHECK-NEXT:     SCEV assumptions:
; CHECK-EMPTY:
; CHECK-NEXT:     Expressions re-written:

define void @forked_ptrs_vector_gep(ptr nocapture readonly %Base1, ptr nocapture readonly %Base2, ptr nocapture %Dest, ptr nocapture readonly %Preds) {
entry:
  br label %for.body

for.body:
  %indvars.iv = phi i64 [ 0, %entry ], [ %indvars.iv.next, %for.body ]
  %arrayidx = getelementptr inbounds i32, ptr %Preds, i64 %indvars.iv
  %0 = load i32, ptr %arrayidx, align 4
  %cmp1.not = icmp eq i32 %0, 0
  %spec.select = select i1 %cmp1.not, ptr %Base2, ptr %Base1
  %.sink.in = getelementptr inbounds <4 x float>, ptr %spec.select, i64 %indvars.iv
  %.sink = load <4 x float>, ptr %.sink.in, align 4
  %1 = getelementptr inbounds <4 x float>, ptr %Dest, i64 %indvars.iv
  store <4 x float> %.sink, ptr %1, align 4
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 4
  %exitcond.not = icmp eq i64 %indvars.iv.next, 100
  br i1 %exitcond.not, label %for.cond.cleanup, label %for.body

for.cond.cleanup:
  ret void
}
