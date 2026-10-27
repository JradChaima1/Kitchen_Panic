# Kitchen Panic

A cooperative Twitch game built in Godot 4.7 (Mobile renderer, GDScript).
Twitch chat discovers hidden ingredients and tools by typing their names.
The streamer drags discovered items onto kitchen stations to cook customers'
orders before their patience runs out.

## Core loop
1. A customer arrives with a recipe. The required items are hidden.
2. Chat types item names (or aliases). A correct guess reveals the item and adds
   it to the shared inventory, crediting the viewer's username.
3. The streamer drags items onto stations. Each step needs the right tool and
   inputs and produces an intermediate item.
4. Serving the finished dish before patience hits zero earns a reward.
   Otherwise the customer leaves.
5. Recipes get harder over time.

## Hard rules
- GDScript only, tabs for indentation, static typing where practical.
- Data-driven: items and recipes are custom Resources (ItemData, RecipeStep,
  RecipeData) stored as .tres files in data/items and data/recipes. Adding a
  recipe must never require code changes.
- Systems talk through the EventBus autoload (signals), not direct references.
- UI is a 2D Control overlay (CanvasLayer). Drag and drop uses Godot's built-in
  Control drag and drop. No 3D raycast dragging.
- Do NOT import any new .glb/.gltf/.fbx files. Large models crashed the importer
  on the target machine. The one existing stove model (Stove.glb) is already
  imported and working, so leave it alone. Build all other 3D items from
  primitives (ItemFactory) and render icons from them.
- Chat input is abstracted behind one interface, so the fake chat box and the
  real Twitch connection are interchangeable. Both emit
  EventBus.chat_message_received(username, text).
- Twitch integration scope: chat only (read-only IRC over WebSocket,
  wss://irc-ws.chat.twitch.tv:443, nick "justinfan" plus random digits, no OAuth).
  The channel name comes from a config file or a UI field, never hardcoded.
  Do not build Twitch Extensions. EventSub or Helix features are optional extras,
  added only after the chat version works.
- Do NOT use the Twitch Unity/Unreal/GameMaker game engine plugins (they do not
  support Godot). Use plain GDScript with WebSocketPeer. If Helix or EventSub is
  added later, use HTTPRequest and WebSocketPeer with the Device Code Flow.
- Never commit secrets. Keep .godot/ in .gitignore.

## Scene facts (do not break)
- scenes/kitchen.tscn is a hand-built 3D scene. Never edit it directly as text
  and never delete its nodes. To add nodes, write an EditorScript in tools/ that
  adds them under the open scene with owners set, and that replaces its own
  previous output when re-run.
- Room spans x -8..8 and z -6..6. Isometric orthographic camera at (15,15,15).
- Existing top-level nodes: CameraRig, DirectionalLight3D, WorldEnvironment,
  Floor, Walls, Windows, Door, Furniture.
- Left-wall kitchen row at x=-7.3 (rotation 0,90,0): stove model in the back
  corner, then counters, then the sink. Two islands in the middle, an L-shaped
  service counter, and a dining area at the front right.
- Stations are Area3D nodes under a new "Stations" node, with station_id matching
  RecipeStep.station: cutting_board, stove, prep_table, sink.
- When creating meshes or materials in scripts, make each one unique. Shared
  resources caused visual bugs before.

## Palette and style
lavender B8A4E3, yellow FFE066, teal 6FD3C4, mint 8FD9B6, cream FFF3DC,
wood D9954F, brown 8B4A2B, coral FF7F7F. Cute, toy-like pastel plastic.

## Workflow
- One feature per task. Propose a short plan first, then implement.
- After each task: list the files changed, how to test it in the Godot editor,
  and a suggested commit message.
- Keep the project runnable at all times (F5 must work).
- Update README.md run instructions when behavior changes.

## Definition of done for the hackathon
- Runs from a fresh clone on Godot 4.7 with no extra downloads.
- Works with the fake chat box AND with a real Twitch channel name.
- A viewer typing a correct item name in real Twitch chat visibly reveals it.ss
