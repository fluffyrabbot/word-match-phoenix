defmodule Mix.Tasks.GameBot.DbTestDiagnose do
  @moduledoc """
  Mix task to diagnose database test issues.

  This task provides tools to diagnose and fix common database test failures,
  especially the "could not lookup Ecto repo" errors.

  ## Usage

  ```
  # Run diagnostics and show status report
  mix game_bot.db_test_diagnose

  # Run diagnostics and attempt automatic repairs
  mix game_bot.db_test_diagnose --repair

  # Run diagnostics and save report to a file
  mix game_bot.db_test_diagnose --output=report.txt
  ```
  """

  use Mix.Task
  require Logger

  @shortdoc "Diagnose database test issues"

  def run(args) do
    # Parse command line arguments
    {opts, _, _} = OptionParser.parse(args,
      switches: [repair: :boolean, output: :string],
      aliases: [r: :repair, o: :output]
    )

    # Start required applications
    IO.puts("Starting required applications...")
    {:ok, _} = Application.ensure_all_started(:postgrex)
    {:ok, _} = Application.ensure_all_started(:ecto)

    # Import modules needed for diagnosis
    IO.puts("Loading diagnostic modules...")
    Code.ensure_loaded(GameBot.Test.DatabaseDiagnostics)
    Code.ensure_loaded(GameBot.Test.DatabaseConfig)
    Code.ensure_loaded(Ecto.Adapters.SQL.Sandbox)

    # Run diagnostics
    IO.puts("\n==== DATABASE DIAGNOSTICS ====\n")

    # Generate report
    report = GameBot.Test.DatabaseDiagnostics.generate_status_report()

    # Display report to console
    IO.puts(report)

    # Save report to file if requested
    if output_file = opts[:output] do
      File.write!(output_file, report)
      IO.puts("\nReport saved to: #{output_file}")
    end

    # Attempt repair if requested
    if opts[:repair] do
      IO.puts("\n==== ATTEMPTING AUTOMATIC REPAIRS ====\n")

      case GameBot.Test.DatabaseDiagnostics.repair_environment() do
        :ok ->
          IO.puts("✓ Repairs completed successfully")

        {:error, {stage, reason}} ->
          IO.puts("✗ Repairs failed at stage '#{stage}': #{inspect(reason)}")
          IO.puts("  You may need to perform manual cleanup.")
      end
    end

    # Display help message
    unless opts[:repair] do
      IO.puts("\nTo attempt automatic repairs, run: mix game_bot.db_test_diagnose --repair")
    end
  end
end
