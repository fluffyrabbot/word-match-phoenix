## SpecStory

## Configuring ElixirLS in VSCode (3/8/2025, 1:47:03 PM)

_**User**_

where do i set this setting in vscode cursor code

---

_**Assistant**_

To set the `elixirLS.projectDir` in Visual Studio Code, follow these steps:

1. **Open Settings**:
   - Click on the gear icon in the lower left corner of the VSCode window.
   - Select "Settings" from the menu.

2. **Search for ElixirLS Settings**:
   - In the search bar at the top of the Settings pane, type `elixirLS.projectDir`.

3. **Edit the Setting**:
   - You should see the `ElixirLS: Project Dir` setting.
   - Click on "Edit in settings.json" (usually a small pencil icon or a link).

4. **Add the Setting**:
   - In the `settings.json` file, add the following line, replacing `your_project_path` with the path to your project directory:

   ```json
   "elixirLS.projectDir": "game_bot"
   ```

5. **Save and Restart**:
   - Save the `settings.json` file.
   - Restart VSCode to apply the changes.

This should configure the ElixirLS extension to recognize the correct project directory.

---

_**User**_

@settings.json is this valid filepath formatting?

---

_**Assistant**_

No, `@settings.json` is not a valid filepath. In Visual Studio Code, the settings file is typically located at:

- **User Settings**: `C:\Users\<YourUsername>\AppData\Roaming\Code\User\settings.json` on Windows.
- **Workspace Settings**: Inside the `.vscode` folder in your project directory, named `settings.json`.

You can access and edit these settings directly through the VSCode interface as described in the previous steps.

---

_**User**_

sorry, i was unclear

C:\Users\ktw30\apps\word match phoenix\.vscode\settings.json

this is my path for environment settings.

---

_**Assistant**_

Got it! Your path looks correct for the environment settings in Visual Studio Code. You can edit the `settings.json` file located

---



---

