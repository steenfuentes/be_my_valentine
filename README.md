# Be My Valentine

An interactive Valentine's Day web app with a playful question flow and a heart-shaped cellular automaton visualization.

They'll think it's a great idea and just won't be able to say no...

## Features

- **Dodging "No" Button**: The No button evades clicks and shrinks with each attempt
- **Celebration Animation**: Particle system with hearts and confetti
- **Heart Automaton**: Conway's Game of Life seeded in a heart shape with personalized initials overlay
- **Fully Configurable**: Personalize recipient name, initials, and messages via environment variables

## Quick Start

```sh
# Install dependencies
npm install

# Copy and configure environment
cp .env.example .env

# Start development server
npm run dev
```

## Configuration

Create a `.env` file with the following variables:

| Variable | Description |
|----------|-------------|
| `PUBLIC_RECIPIENT_NAME` | Name in greeting (e.g., `Jane`) |
| `PUBLIC_INITIALS` | Initials on automaton, format: `X + Y` |
| `PUBLIC_PAGE_TITLE` | Browser tab title |
| `PUBLIC_CELEBRATION_MESSAGE` | Message after "Yes" click |
| `PUBLIC_AUTOMATON_TITLE` | Title on automaton HUD |

### Tooltip Messages

Back button tooltips are configured in `src/lib/config/tooltips.json`:

```json
{
  "backButton": {
    "celebration": ["message1", "message2", ...],
    "automaton": ["message1", "message2", ...]
  }
}
```

- **celebration**: Messages shown when hovering the back button on the celebration screen
- **automaton**: Messages shown when hovering the back button on the automaton screen

Messages rotate randomly on each hover without repeating until all have been displayed.

## Development

```sh
npm run dev          # Start dev server at localhost:5173
npm run build        # Build for production
npm run preview      # Preview production build
npm run check        # Run svelte-check
```

## Docker

Use the Makefile for simplified Docker commands:

```sh
make help            # Show all available commands
make dev             # Start dev server with hot reload
make prod            # Start production server (port 3000)
make prod-build      # Rebuild and start production
make clean           # Stop containers and remove images
```

Or use Docker Compose directly:

```sh
docker compose --profile dev up        # Development
docker compose --profile prod up -d    # Production
```

## Tech Stack

- **Framework**: SvelteKit with TypeScript
- **Styling**: Scoped CSS with CSS variables
- **Build**: Vite + adapter-static (SPA output)
- **Deployment**: Nginx via Docker

## Project Structure

```
src/
├── lib/config/       # JSON configuration (tooltips)
├── routes/
│   └── +page.svelte  # Main app (all phases)
.env.example          # Environment variable template
Dockerfile            # Production build
docker-compose.yml    # Dev and prod services
Makefile              # Docker command shortcuts
```
