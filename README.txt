SUPPLEMENTARY MATERIAL
======================
"The Semantic Top: Why Discovery-Capable AI Requires Hierarchical Semantic Constraint"
Submitted to Minds and Machines

----------------------------------------------------------------------
CONTENTS OF THIS ARCHIVE
----------------------------------------------------------------------

  shuffle_test.pl     — Domain process ontology (Level 2 input)
  process_model.pl    — Inference engine with Level 3 archetypal constraint
  patterns.pl         — Universal verb-pattern registry (Level 3 vocabulary)

These three files constitute the complete, self-contained implementation
of the shuffle-test experiment reported in §8 of the paper.  No other
files are required to reproduce the results.

----------------------------------------------------------------------
WHAT THE EXPERIMENT DEMONSTRATES
----------------------------------------------------------------------

The paper claims that a two-level semantic constraint — (Level 3)
universal archetypal process patterns plus (Level 2) a sparse domain
ontology — can deterministically collapse the ordering entropy of a
randomly shuffled process to zero.

The experiment operationalises this claim as follows:

  Input:   the 42 process steps of a retail sales fulfilment process,
           presented in random (shuffled) order.

  Task:    restore the canonical ordering using only the semantic
           constraints encoded in the three files above, without
           access to the original sequence or any lookup table.

  Metric:  Kendall-tau inversions — the number of step-pairs that
           appear in the wrong relative order after reordering.
           Zero inversions = perfect recovery of canonical order.

  Result:  the engine reduces inversions from an average of 430
           (expected from a uniform random shuffle of 42 items,
           ~169 bits of ordering entropy) to exactly 0 across all
           trials, deterministically.

The contribution of each architectural level is separable and was
measured independently (see Table 1 in §8):

  Level 3 alone (no domain facts):   430 → ~325 inversions
  Level 3 + 18 object_sequence facts: 430 → 0 inversions
  Level 3 + all 42 domain facts:      430 → 0 inversions

The 24 process_step_precedes constraints (rows 2 vs 3 in Table 1)
are redundant: the engine re-derives them by transitive closure from
the 18 object_sequence facts and the archetypal patterns.  The
load-bearing residue is 18 declarative facts.

----------------------------------------------------------------------
FILE DESCRIPTIONS
----------------------------------------------------------------------

shuffle_test.pl
  The domain process ontology for the experiment.  Contains:
  - The 42 normalised process steps (normalized_step/7 facts) in
    shuffled presentation order — these are the engine's input.
  - 18 object_sequence/4 facts encoding lifecycle ordering
    constraints between domain objects (Level 2 ontology).
  - 24 process_step_precedes/3 facts (redundant; included for
    completeness; removing them does not change the result).
  - process_start_step/2 declaring the canonical first step.
  The module name is process_library_shuffle_test.

process_model.pl
  The core inference engine.  Key exported predicates:
    order_process/2   — takes an unordered action list, returns
                        the semantically ordered list.
    order_process/3   — same, with a status term.
  Internally, the engine:
    (1) builds a directed constraint graph from object_sequence,
        process_step_precedes, actor-serialisation, and lifecycle
        edges (Level 2 + Level 3 combined);
    (2) resolves conflicting edges by priority rules;
    (3) runs priority_topo_sort_full/3, a scored topological sort
        that uses the Level 3 archetypal scoring function
        (score_topo_candidate/4) to break ties deterministically.
  The Level 3 archetypal constraint is embodied in the edge-building
  predicates (build_lifecycle_edges/2, build_aux_actor_edges/2, etc.)
  and in the scoring function — not in any domain-specific knowledge.

patterns.pl
  The universal verb-pattern registry.  Maps 3-letter pattern codes
  (e.g. trf(), rcv(), crt()) to canonical English verb labels and
  classifies each pattern as source-directed, receptor-directed, or
  neutral.  This file encodes the Actor/Object/Tool/Result role
  vocabulary referenced throughout the paper as the Level 3
  archetypal layer.

----------------------------------------------------------------------
HOW TO RUN THE EXPERIMENT
----------------------------------------------------------------------

Requirements:
  SWI-Prolog 9.x (https://www.swi-prolog.org/Download.html)
  No additional packages or libraries required.

Setup:
  Place all three files in the same directory.

  Edit the two use_module paths at the top of shuffle_test.pl if
  needed so that process_model and patterns resolve correctly, e.g.:

    :- use_module('process_model').
    :- use_module('patterns').

  (In the original repository layout the paths are relative;
  flat placement in one directory requires this adjustment.)

Run:
  $ swipl shuffle_test.pl

  Then at the Prolog prompt:

    ?- use_module(process_model).
    ?- use_module(library(process_library_shuffle_test)).

    % Load the shuffled steps:
    ?- normalized_actions(Actions).

    % Run the ordering engine:
    ?- order_process(Actions, Ordered).

    % Ordered is the recovered canonical sequence.
    % Compare it against the normalized_step/7 facts in
    % shuffle_test.pl (step IDs sr1 .. sr42) to verify
    % zero inversions.

To replicate the ablation (Level 3 only, no domain facts):
  Comment out or remove all object_sequence/4 facts from
  shuffle_test.pl and re-run.  The engine will still partially
  recover order (Level 3 contribution), but inversions will
  not reach zero.

----------------------------------------------------------------------
