%{
  configs: [
    %{
      name: "default",
      files: %{included: ["bench/", "lib/", "test/"], excluded: []},
      strict: true
    }
  ]
}
