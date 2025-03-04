defmodule GameBot.Domain.WordServiceTest do
  use ExUnit.Case, async: true

  alias GameBot.Domain.WordService

  @test_dict_path "priv/dictionaries/dictionary.txt"
  @test_variations_path "priv/dictionaries/word_variations.json"

  setup_all do
    # Create test dictionary files
    File.mkdir_p!(Path.dirname(@test_dict_path))
    File.write!(@test_dict_path, """
    cat
    cats
    dog
    dogs
    run
    running
    ran
    be
    was
    color
    colour
    colors
    colored
    analyze
    analyse
    analyzing
    analyses
    theater
    theatre
    theatres
    box
    boxes
    happy
    sad
    walk
    """)

    File.write!(@test_variations_path, """
    {
      "color": ["colour", "colors", "colored"],
      "analyze": ["analyse", "analyzing", "analyses"],
      "theater": ["theatre", "theatres"]
    }
    """)

    # Stop any existing WordService
    if pid = Process.whereis(WordService) do
      Process.exit(pid, :normal)
      # Wait for process to terminate
      ref = Process.monitor(pid)
      receive do
        {:DOWN, ^ref, :process, ^pid, _} -> :ok
      after
        1000 -> :ok
      end
    end

    # Start WordService once for all tests
    {:ok, pid} = WordService.start_link()
    {:ok, _} = WordService.load_dictionary()

    on_exit(fn ->
      # Clean up test files
      File.rm!(@test_dict_path)
      File.rm!(@test_variations_path)
    end)

    %{word_service: pid}
  end

  test "loads dictionary successfully" do
    assert {:ok, _count} = WordService.load_dictionary()
  end

  test "validates words correctly" do
    assert WordService.valid_word?("cat")
    assert WordService.valid_word?("dog")
    refute WordService.valid_word?("xyz123")
    refute WordService.valid_word?("")
  end

  test "generates random words" do
    word = WordService.random_word()
    assert is_binary(word)
    assert String.length(word) > 0
    assert WordService.valid_word?(word)

    # Test that we get different words
    words = for _ <- 1..10, do: WordService.random_word()
    assert length(Enum.uniq(words)) > 1
  end

  test "matches exact words" do
    assert WordService.match?("cat", "cat")
    assert WordService.match?("dog", "dog")
    refute WordService.match?("cat", "dog")
  end

  test "matches US/UK spelling variations" do
    assert WordService.match?("color", "colour")
    assert WordService.match?("analyze", "analyse")
    assert WordService.match?("theater", "theatre")
  end

  test "matches singular/plural forms" do
    assert WordService.match?("cat", "cats")
    assert WordService.match?("dog", "dogs")
    assert WordService.match?("box", "boxes")
  end

  test "matches lemmatized forms" do
    assert WordService.match?("run", "running")
    assert WordService.match?("run", "ran")
    assert WordService.match?("be", "was")
  end

  test "does not match unrelated words" do
    refute WordService.match?("cat", "dog")
    refute WordService.match?("run", "walk")
    refute WordService.match?("happy", "sad")
  end

  test "returns variations of a word" do
    variations = WordService.variations("color")
    assert "colour" in variations
    assert "colors" in variations
    assert "colored" in variations
  end

  test "returns base form of a word" do
    assert WordService.base_form("running") == "run"
    assert WordService.base_form("cats") == "cat"
    assert WordService.base_form("was") == "be"
  end

  test "combines variations from file and pattern-based rules" do
    variations = WordService.variations("analyze")
    assert "analyse" in variations
    assert "analyzing" in variations
    assert "analyses" in variations
  end

  test "matches words using both file and pattern-based variations" do
    assert WordService.match?("analyze", "analysing")
    assert WordService.match?("color", "coloured")
    assert WordService.match?("theater", "theatres")
  end
end
