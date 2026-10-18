%Doctor.Config{
  # Mix tasks are documented through @shortdoc/@moduledoc and covered by tests;
  # the generated chunk modules are internal. Public library API must be documented.
  ignore_paths: [
    ~r{^test/}
  ],
  ignore_modules: [~r/^Hugeicons\.Chunks\./],
  min_module_doc_coverage: 100,
  min_module_spec_coverage: 90,
  min_overall_doc_coverage: 100,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 90,
  exception_moduledoc_required: true,
  struct_type_spec_required: true,
  raise: true,
  reporter: Doctor.Reporters.Summary,
  umbrella: false
}
