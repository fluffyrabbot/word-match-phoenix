## SpecStory

## Creating Cursorrules Files for AI Manifest (3/4/2025, 2:57:05 AM)

_**User**_

do you know how to create cursorrules files such that the ai can see my manifest 

---

_**Assistant**_

Below is an explanation and an example of how you might create a **cursorrules** file that includes your manifest so the AI can refer to it. Note that the AI (or any other process) can only “see” your manifest if its contents are provided explicitly (for example, pasted into the prompt or read by an integration), since the AI can’t access files on your local filesystem on its own.

---

### What Is a Cursorrules File?

A cursorrules file is essentially a configuration file that holds key information—such as a project manifest and a list of rules or guidelines. This can be useful when you want to define parameters that an AI should follow (for instance, ensuring that architectural principles are respected) without hard-coding these constraints into every prompt.

For the AI to “see” your manifest, you need to either:

- **Integrate it into your prompt:** Copy and paste the contents of the file (or a reference summary) so that the AI can parse it.  
- **Have an integration module:** Use a plugin or external system that reads the configuration file and presents its contents during AI invocation.

---

### Example Format

A common approach is to use a YAML file for its readability and ease of parsing. Below is an example of a cursorrules file containing a manifest and some example rules (note that you should adjust its contents according to your project’s specifics):

```yaml:cursorrules.yaml
manifest:
  name: "My Project"
  description: "This manifest defines the core principles and rules for the AI regarding project implementation. Follow the established design patterns and module boundaries."
  version: "1.0.0"
  author: "Your Name"
rules:
  - "Only implement features explicitly requested."
  - "Maintain established module boundaries."
  - "Follow existing design patterns and use appropriate components."
  - "Report any inconsistencies rather than making unapproved changes."
```

---

### How to Use It

1. **Store the file in your repository**  
   Place the cursorrules file (e.g., `cursorrules.yaml`) in a location known to your integration layer. Often, projects keep configuration at the root or in a dedicated directory, like `/config`.

2. **Load the File into Your Integration**  
   When your application starts or when you invoke the AI (for example, as part of a command handler), have your integration read the cursorrules file. In Elixir, for instance, you might use the [YAML Elixir library](https://github.com/KamilLelonek/yaml-elixir) to parse the file.

3. **Present the Manifest Data to the AI**  
   Make sure that the critical parts of your manifest are included in the prompt or context provided to the AI. For example, you could build your prompt dynamically by merging your manifest details with the conversation context.

---

### Example Integration Snippet in Elixir

Below is a short Elixir function that reads a YAML cursorrules file and prepares its manifest content for use. (This snippet is intended for illustration; adjust paths and error handling as needed.)

```elixir:file:lib/my_app/cursor_rules_loader.ex
defmodule MyApp.CursorRulesLoader do
  @moduledoc """
  Loads the cursorrules file and returns the manifest.
  """

  @cursorrules_path "config/cursorrules.yaml"

  def load_manifest do
    with {:ok, yaml_content} <- File.read(@cursorrules_path),
         {:ok, data} <- YamlElixir.read_from_string(yaml_content) do
      Map.get(data, "manifest")
    else
      error ->
        IO.warn("Failed to load cursorrules: #{inspect(error)}")
        %{}
    end
  end
end
```

---

### Final Notes

- **Visibility:** The AI won’t have automatic access to files on your system. The integration must supply the manifest content as part of the AI’s context.
- **Customizations:** Adjust the file format and contents as needed for your environment or any specific requirements you have.
- **Project Guidelines:** As your project guidelines require adherence to architectural constraints, ensure that any integration that loads this file does not bypass the established module boundaries and design patterns.

If you need further adjustments or have additional details about your intended setup, feel free to ask!

---



---

