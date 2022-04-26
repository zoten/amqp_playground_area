%{
  configs: [
    %{
      name: "default",
      strict: true,
      parse_timeout: 60_000,
      #
      # These are the files included in the analysis:
      files: %{
        #
        # You can give explicit globs or simply directories.
        # In the latter case `**/*.{ex,exs}` will be used.
        #
        included: ["*.exs", "lib/", "src/", "test/", "web/", "apps/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: [
        #
        ## Consistency Checks
        #
        {Credo.Check.Consistency.ExceptionNames},
        {Credo.Check.Consistency.LineEndings},
        {Credo.Check.Consistency.ParameterPatternMatching},
        {Credo.Check.Consistency.SpaceAroundOperators},
        {Credo.Check.Consistency.SpaceInParentheses},
        {Credo.Check.Consistency.TabsOrSpaces},

        #
        ## Design Checks
        #
        # You can customize the priority of any check
        # Priority values are: `low, normal, high, higher`
        #
        {Credo.Check.Design.AliasUsage, priority: :low, if_called_more_often_than: 2, if_nested_deeper_than: 1},
        # {Credo.Check.Design.AliasUsage, priority: :low, if_called_more_often_than: 2, if_nested_deeper_than: 1, excluded_lastnames: ["Conn"]},
        # For some checks, you can also set other parameters
        #
        # If you don't want the `setup` and `test` macro calls in ExUnit tests
        # or the `schema` macro in Ecto schemas to trigger DuplicatedCode, just
        # set the `excluded_macros` parameter to `[:schema, :setup, :test]`.
        #
        {Credo.Check.Design.DuplicatedCode, excluded_macros: []},
        # You can also customize the exit_status of each check.
        # If you don't want TODO comments to cause `mix credo` to fail, just
        # set this value to 0 (zero).
        #
        # NOTE(luca.deizotti) at this stage TODO tags are allowed
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Design.TagFIXME},

        #
        ## Readability Checks
        #
        {Credo.Check.Readability.AliasOrder},
        {Credo.Check.Readability.FunctionNames},
        {Credo.Check.Readability.LargeNumbers},
        # already checked by formatter
        {Credo.Check.Readability.MaxLineLength, false},
        {Credo.Check.Readability.ModuleAttributeNames},
        {Credo.Check.Readability.ModuleDoc,
         ignore_names: [
           ~r/(\.\w+Controller|\.Endpoint|\.Repo|\.Router|\.\w+Socket|\.\w+View|\.\w+Test|Mixfile)$/
         ]},
        {Credo.Check.Readability.ModuleNames},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs},
        {Credo.Check.Readability.ParenthesesInCondition},
        {Credo.Check.Readability.PredicateFunctionNames},
        {Credo.Check.Readability.PreferImplicitTry},
        {Credo.Check.Readability.RedundantBlankLines},
        {Credo.Check.Readability.StringSigils},
        {Credo.Check.Readability.TrailingBlankLine},
        {Credo.Check.Readability.TrailingWhiteSpace},
        {Credo.Check.Readability.VariableNames},
        {Credo.Check.Readability.Semicolons},
        {Credo.Check.Readability.SpaceAfterCommas},

        #
        ## Refactoring Opportunities
        #
        {Credo.Check.Refactor.DoubleBooleanNegation},
        {Credo.Check.Refactor.CondStatements},
        {Credo.Check.Refactor.CyclomaticComplexity},
        {Credo.Check.Refactor.FunctionArity},
        {Credo.Check.Refactor.LongQuoteBlocks},
        # not available in elixir 1.9
        {Credo.Check.Refactor.MapInto, false},
        {Credo.Check.Refactor.MatchInCondition},
        {Credo.Check.Refactor.PipeChainStart,
         excluded_argument_types: ~w(atom binary fn keyword)a, excluded_functions: ~w(from)},
        {Credo.Check.Refactor.CyclomaticComplexity},
        {Credo.Check.Refactor.NegatedConditionsInUnless},
        {Credo.Check.Refactor.NegatedConditionsWithElse},
        {Credo.Check.Refactor.Nesting, max_nesting: 3},
        {Credo.Check.Refactor.PipeChainStart,
         excluded_argument_types: [:atom, :binary, :fn, :keyword], excluded_functions: []},
        {Credo.Check.Refactor.UnlessWithElse},

        #
        ## Warnings
        #
        {Credo.Check.Warning.BoolOperationOnSameValues},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck},
        {Credo.Check.Warning.IExPry},
        {Credo.Check.Warning.IoInspect},
        # not available in elixir 1.9
        {Credo.Check.Warning.LazyLogging, false},
        {Credo.Check.Warning.OperationOnSameValues},
        {Credo.Check.Warning.OperationWithConstantResult},
        {Credo.Check.Warning.UnusedEnumOperation},
        {Credo.Check.Warning.UnusedFileOperation},
        {Credo.Check.Warning.UnusedKeywordOperation},
        {Credo.Check.Warning.UnusedListOperation},
        {Credo.Check.Warning.UnusedPathOperation},
        {Credo.Check.Warning.UnusedRegexOperation},
        {Credo.Check.Warning.UnusedStringOperation},
        {Credo.Check.Warning.UnusedTupleOperation},
        {Credo.Check.Warning.RaiseInsideRescue},

        #
        # Controversial and experimental checks (opt-in, just remove `, false`)
        #
        # {Credo.Check.Refactor.ABCSize, max_size: 40},
        {Credo.Check.Refactor.ABCSize, max_size: 60},
        {Credo.Check.Refactor.AppendSingleItem, false},
        {Credo.Check.Refactor.VariableRebinding, false},
        {Credo.Check.Warning.MapGetUnsafePass, false},
        {Credo.Check.Consistency.MultiAliasImportRequireUse, false},

        #
        # Deprecated checks (these will be deleted after a grace period)
        #
        {Credo.Check.Readability.Specs, false}

        #
        # Custom checks can be created using `mix credo.gen.check`.
        #

        # Naming
        # https://github.com/mirego/credo_naming
        # Let's try to avoid black holes/catchall modules
        # Excluding stuff that comes with Phoenix etc
        # {
        #   CredoNaming.Check.Warning.AvoidSpecificTermsInModuleNames,
        #   terms: ["Manager", ~r/Helpers?/],
        #   excluded_paths: []
        # },
        # Enforce consistency between file names and module names
        # {CredoNaming.Check.Consistency.ModuleFilename}
      ]
    }
  ]
}
