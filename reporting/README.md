The `test-grid-reporting` package contains the
reporting code we will consider below. 

``` shell
$ git clone git@github.com:cl-test-grid/cl-test-grid.git
```

``` common-lisp
CL-USER> (pushnew "cl-test-grid/" asdf:*central-registry* :test #'equal)
CL-USER> (ql:quickload :test-grid-reporting)
```
The package doesn't export public functions, so lets enter it:
``` common-lisp
CL-USER> (in-package #:test-grid-reporting)
```

Accessing the Test Results Database
===================================

To access test results from the `test-grid-storage` named "main"
you may do the following:

``` common-lisp
TEST-GRID-REPORTING> (ql:quickload :test-grid-storage)

TEST-GRID-REPORTING> (defparameter *db-snapshot-file*
                       (asdf:system-relative-pathname :test-grid-storage
                                                      "db-main.lisp"))
TEST-GRID-REPORTING> (defparameter *r* (tg-storage:make-replica "main" *db-snapshot-file*))
;; Incrementally synchronize the local replica with the online db.
;; First time it loads the full db and may take a minute or two;
;; you may observe progress in the REPL buffer.
;; Next time synchronization only fetches new changes and is performed faster.
TEST-GRID-REPORTING> (tg-storage:sync *r*)
TEST-GRID-REPORTING> (defparameter *db* (tg-storage:data *r*))
```

Or, if you want to work with old test results archived in a plain s-expression
file at https://github.com/cl-test-grid/cl-test-grid-results do the following:

``` shell
$ git clone git@github.com:cl-test-grid/cl-test-grid-results.git
```

``` common-lisp
TEST-GRID-REPORTING> (defparameter *db* (test-grid-data:read-archive))
```

`RESULT` Objects
==================

In most cases we found it convenient to convert
the database into a large list of `result` objects:

``` common-lisp
TEST-GRID-REPORTING> (defparameter *all-results* (list-results *db*))
```

Having a list of `result` it is easy to filter
and match them using standard Common Lisp functions.

The most interesting properties of the `result` objects
are accessed using the following functions:

- `(result-spec result)` Result description in one of the following forms:
    - `(:load "some-asdf-system-name" [:ok | :fail | :crash | :timeout])`

       Returned if the result object represents result of loading an ASDF system.
       Here the notation `[:ok | :fail | :crash | :timeout]` should be read as "one of `:ok`, `:fail`, `:crash` or `:timeout`".
    
       `:ok` means the load operation succeeded;

       `:fail` means the load operation failed;

       `:crash` means the child lisp process loading asdf
                system exited without returning a result;            

       `:timeout` means that the child lisp process
                  hasn't finished in a specified timeout time.

    - `(:test-case "some-test-case-name" [:fail | :known-fail | :unexpected-ok])`

        Represents abnormal result of a single test case.

        `:fail` means the test case has failed;

        `:known-fail` also means that the test case has failed, but
                      the library developers have this testcase
                      marked as a known failure (known failures is a feature
                      provided by some test frameworks; it may be used
                      by the developers, for example, to mark
                      test cases which are impossible to fix right now,
                      maybe due to lack of support or bugs
                      in CL implementations, 3rd party libraries, or similar);

        `:unexpected-ok` means the testcase marked as known failure has not failed.

    - `(:whole-test-suite [:ok | :no-resource | :fail | :crash | :timeout])`

       Result for a whole test suite.

       `:ok` None of the testcases has failed.

       `:fail` Either some test cases failed but the test
               framework does not allow to distinguish
               particular test case, or some problem
               prevented the test suite from running at all.
               Example of such a problem may be that the
               testsuite or one of it's dependencies
               doesn't compile/load due to errors
               in lisp code; or absense of necessary
               foreign library on the test system.

       `:no-resource` This status is designed to represent
         situations when testsuite can not be run due
         to absense of necessary environment.

         For example, CFFI test suite needs a small
         C library to be build. On Windows user must
         do it manually. If this library is not found,
         testgrid adapter of the CFFI test suite returns `:no-resource`.
         
         Or, external-program test suite can only be
         run on *nix platforms. On Windows testgrid
         adapter returns `:no-resource`.

         The :no-resource handling in testsuite adapters
         is optional, as every testsuite may have different
         requirements.

         Today, most testsuite adapters in testgrid
         do not implement such a handling, and
         in case of any problems when running
         the tests `:fail` is recorded.

       `:crash` means the child lisp process running the test suite
         terminated without returning a result;

       `:timeout` means that the child lisp process
         hasn't finished in a specified timeout.

- `(libname result)` Name of the library tested - a keyword, like `:babel`, `:alexandria`, etc.

- `(lisp result)` Lisp implementation identifier - a string, for example `"clisp-2.49-unix-x86_64"`,
   `"cmu-20c_release-20c__20c_unicode_-linux-x86"`, `"sbcl-1.0.54-linux-x64"`

- `(lib-world result)` A string naming the set of libraries and their versions used during testing,
  for example `"quicklisp 2012-07-03"`, `"quicklisp 2012-08-11"`.

- `(system-name result)` If the result describes ASDF system load result, then the
  name of that ASDF system - a string, like `"arnesi"`, `"anaphora"`.
  Otherwise =NIL=.

- `(log-uri result)` URI of the stored online output produced by the child lisp process
  performed the test suite or tested the ASDF system load.

For example, lets find all the alexandria results on quickisp 2012-09-09:
``` common-lisp
TEST-GRID-REPORTING> (remove-if-not (lambda (result)
                                      (and (eq :alexandria (libname result))
                                           (string= "quicklisp 2012-09-09" (lib-world result))))
                                    *all-results*)

=> (#<RESULT "quicklisp 2012-09-09" "abcl-1.0.1-svn-13750-13751-fasl38-macosx-java" :ALEXANDRIA (:WHOLE-TEST-SUITE :FAIL) "http://cl-test-grid.appspot.com/blob?key=388372" #x2106FA376D>
    #<RESULT "quicklisp 2012-09-09" "ecl-12.7.1-dfc94901-linux-x86-lisp-to-c" :ALEXANDRIA (:LOAD "alexandria" :OK) "http://cl-test-grid.appspot.com/blob?key=389242" #x2106FD890D>
    #<RESULT "quicklisp 2012-09-09" "ecl-12.7.1-dfc94901-linux-x86-lisp-to-c" :ALEXANDRIA (:LOAD "alexandria-tests" :OK) "http://cl-test-grid.appspot.com/blob?key=386272" #x2106FD887D>
    ...)
```
For better readability, package `test-grid-reporting`
defines the following function instead of `cl:remove-if-not`:
``` common-lisp
(defun subset (superset predicate &key key)
  (remove-if-not predicate superset :key key))
```
Example:
``` common-lisp
TEST-GRID-REPORTING> (defparameter *some-results*
                       (subset *all-results*
                               (lambda (result)
                                 (and (member (libname result) '(:alexandria :let-plus))
                                      (member (lib-world result)
                                              '("quicklisp 2012-09-09" "quicklisp 2012-08-11")
                                              :test #'string=)))))
```

Displaying Data - Pivot Tables
==============================

To understand a large result set it is necessary to group
results into groups and further subgroups.

Pivot tables provide a more or less universal solution for
grouping and sorting data according to values of selected
properties of data objects.

Lets layout the `*some-results*` into a pivot:


``` common-lisp
TEST-GRID-REPORTING> (print-pivot "demo/some-results.html"
                                  *some-results*
                                  :rows '((lib-world string>) (lisp string<))
                                  :cols '((libname string<))
                                  :cell-printer (lambda (out cell-data)
                                                  (dolist (result cell-data)
                                                    (format out
                                                            "<a href=\"~A\">~A</a></br>" 
                                                            (log-uri result)
                                                            (result-spec result)))))
```

Please review the resulting file: [cl-test-grid/reports-generated/demo/some-results.html](http://common-lisp.net/project/cl-test-grid/demo/some-results.html).
You may see that the table is build according to the parameters we specified: row headers contain
`lib-world` and `lisp` values, column headers contain `libname`.
The sorting corresponds to what is specified for every field.

The `:cell-printer` parameter is a function responsible for printing set of
results falling into a single pivot cell. The function we pass prints results
in the form of HTML links, so that clicking the result refers to the log file,
where the details may be found.

Such a `:cell-printer` function is often useful, therefore `test-grid-reporting`
defines a ready to use function `results-cell-printer`. So we can write instead:
``` common-lisp
TEST-GRID-REPORTING> (print-pivot "demo/some-results2.html"
                                  *some-results*
                                  :rows '((lib-world string>) (lisp string<))
                                  :cols '((libname string<))
                                  :cell-printer #'results-cell-printer)
```
Please review the resulting file: [cl-test-grid/reports-generated/demo/some-results2.html](http://common-lisp.net/project/cl-test-grid/demo/some-results2.html)
As you see, it is the same table, but `results-cell-printer` 
takes care to colorize the results.

Comparing Results to Find Regressions
=====================================

Lets say we want to compare new version of a compiler with an old version,
to ensure there are no regressions in the new version.

This is easy to do using the tools introduced above. The approach:
- select two subsets of results: of the old compiler and of the new one
- compute `exclusive-or` of these two subsets
- print the result as a pivot where results of two compilers
        are represented side by side

The function `compiler-diff` implements this approach.
See its source code in [cl-test-grid/reporting/compiler-diff.lisp](https://github.com/cl-test-grid/cl-test-grid/blob/master/reporting/compiler-diff.lisp).
Note, it calls `fast-exclusive-or`. This function has exactly the
same prototype as `cl:set-exclusive-or`,
but takes advantage of hash tables if the `:test` parameter
is one of `cl:eq`, `cl:eql`, `cl:equal` or `cl:equalp`.

Lets use `compiler-diff` to compare two versions of ABCL: old release 1.0.1
and some intermediate development version:
``` common-lisp
TEST-GRID-REPORTING> (print-compiler-diff "demo/abcl-diff.html"
                                          *all-results*
                                          "quicklisp 2012-09-09"
                                          "abcl-1.0.1-svn-13750-13751-fasl38-linux-java"
                                          "abcl-1.1.0-dev-svn-14157-fasl39-linux-java")
```

The resulting report is stored in [cl-test-grid/reports-generated/demo/abcl-diff.html](http://common-lisp.net/project/cl-test-grid/demo/abcl-diff.html).
On the left column are the results collected from the old release, but not found in the new release.
On the right column the results collected for the new version, but not
found for the old release.

If the left column has green result and the right has red result, it is a regression.
If the left column has red result and the right has green result, it is an improvement.

Lets compare two versions of Quicklisp.

The same approach: `exclusive-or` of two sets of results: for old
Quicklisp version and for new one.

The source code: [cl-test-grid/reporting/quicklisp-diff.lisp](https://github.com/cl-test-grid/cl-test-grid/blob/master/reporting/quicklisp-diff.lisp).
As you can see, additional care is taken to compare only results
of CL implementation/library/test which were preformed on both
Quicklisp versions and on the same machine.

``` common-lisp
TEST-GRID-REPORTING> (print-quicklisp-diff-report "demo/quicklisp-diff.html"
                                                  *all-results*
                                                  "quicklisp 2012-08-11"
                                                  "quicklisp 2012-09-09")
```
The resulting report is stored in [cl-test-grid/reports-generated/demo/quicklisp-diff.html](http://common-lisp.net/project/cl-test-grid/demo/quicklisp-diff.html).
On the left column are the results collected for the old quicklisp version, but not found in the new version.
On the right column the results collected for the new version, but not found for the old version.


http://common-lisp.net/project/cl-test-grid/testsuites-pivots.html presents results
of all possible pivots of the testsuites tested by testgrid. 
We do not refer you to the source code of these reports, as they are somewhat
outdated - do not include results of ASDF systems loading.

Combining Failures and Dependency Information
=============================================

When some ASDF system fails to load, it blocks all other
systems depending on it.

We can build a report showing which ASDF systems are
the most important to fix.

The most fruitful systems to fix are those which:
  - fail by themselves, i.e. don't have failing dependencies
  - have many other systems depending on the given system
  - in particular, these depending systems have the given system
    as the only failed dependency (we say that the given system
    blocks them exclusively)

For example, on particular (old) version of ECL closer-mop failed to load,
and there are 123 other ASDF systems (related to 59 projects),
which depend on closer-mop and closer-mop is the only failing
dependency for them (in other words, closer-mop blocks them exclusively).

This means that fixing closer-mop is likely to fix 123 other ASDF
systems (unless these other systems have their own problems,
in this case we will at least reveal these problems).

Here is how to build such a report:
``` common-lisp
TEST-GRID-REPORTING> (print-load-failures "demo/ecl-load-failures.html"
                                          *all-results*
                                          "ecl-12.7.1-ce653d88-linux-x86-lisp-to-c"
                                          "quicklisp 2012-09-09")
```

The report is stored at 
[cl-test-grid/reports-generated/demo/ecl-load-failures.html](http://common-lisp.net/project/cl-test-grid/demo/ecl-load-failures.html)

The default sorting is
- number of root-blocker-systems desc,
- number projects of systems blocked exclusively asc
- system name desc.

I.e. the default sorting places the most fruitful systems at the top.

You may change sorting by clicking columns (holding Shift
to sort by multiple columns).

The reports for some CL implementations we have tested:
[ABCL](http://common-lisp.net/project/cl-test-grid/abcl-load-failures.html)
[ACL](http://common-lisp.net/project/cl-test-grid/acl-load-failures.html)
[CCL](http://common-lisp.net/project/cl-test-grid/ccl-load-failures.html)
[CMUCL](http://common-lisp.net/project/cl-test-grid/cmucl-load-failures.html)
[ECL](http://common-lisp.net/project/cl-test-grid/ecl-load-failures.html)
[SBCL](http://common-lisp.net/project/cl-test-grid/sbcl-load-failures.html)

Note, there is no way (or at least it is not trivial) to extract the
dependency information 100% precise. ASDF systems are just lisp code,
sometimes they contain reader conditionals, sometimes
`asdf:load-op` invocations, instead of just putting the systems
into `:depends-on` or `:defsystem-depend-on`. But the information
we can gather is enough to make useful observations. We retrieve
the dependency information from the _quicklisp/dists/quicklisp/systems.txt_
index file.
