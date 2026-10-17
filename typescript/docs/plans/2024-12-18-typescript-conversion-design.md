# Statusline TypeScript Conversion Design

## Beslissingen

| Aspect | Keuze |
|--------|-------|
| UI Framework | React + Ink |
| Runtime | Bun |
| Package manager | Bun |
| Structuur | Multi-file (components/utils/hooks) |
| npm publicatie | Nee, lokaal gebruik |
| Features | Alle bestaande features behouden |

## Project Structuur

```
statusline-claudecode-tim/
├── src/
│   ├── index.tsx              # Entry point, leest stdin en rendert App
│   ├── App.tsx                # Hoofd component, layout van beide lijnen
│   ├── components/
│   │   ├── ModelSegment.tsx   # ✳ Opus 4.5
│   │   ├── DirSegment.tsx     # 󰉋 ~/…/parent/folder
│   │   ├── GitSegment.tsx     # 󰊢 branch ✓ 󰓦 +5 -3
│   │   ├── CommitSegment.tsx  # 󰜘 2h
│   │   ├── ContextSegment.tsx # 󱘲 45% · 89.2k
│   │   ├── UsageSegment.tsx   # 󰪡 32% · 18-12 15:30
│   │   ├── TimeSegment.tsx    # 󱦻 5m23s
│   │   └── Separator.tsx      # " | " met grijze kleur
│   ├── hooks/
│   │   └── useApiUsage.ts     # Fetcht API usage met caching
│   ├── utils/
│   │   ├── colors.ts          # Hex kleuren, getPctColor()
│   │   ├── git.ts             # Git commando's uitvoeren
│   │   ├── oauth.ts           # OAuth token uit Keychain/file
│   │   ├── format.ts          # Tijd formatting, token formatting
│   │   └── icons.ts           # Nerd Font icons
│   └── types.ts               # TypeScript types voor input JSON
├── package.json
├── tsconfig.json
└── statusline-tim.sh          # Bestaande bash versie (backup)
```

## Kleuren (Atom One Dark)

Exact dezelfde hex kleuren als het bash script:

```typescript
export const colors = {
  model:    '#D97857',  // Oranje
  dirIcon:  '#E5C07B',  // Geel
  context:  '#61AFEF',  // Blauw
  git:      '#D19A66',  // Oranje
  usage:    '#C678DD',  // Magenta
  session:  '#98C379',  // Groen
  time:     '#56B6C2',  // Cyan
  gray:     '#808080',
  green:    '#98C379',
  yellow:   '#E5C07B',
  red:      '#E06C75',
};
```

Dynamische kleur op basis van percentage:
- < 60%: originele kleur
- 60-80%: geel
- > 80%: rood

## Data Flow

1. `index.tsx` leest JSON van stdin via `Bun.stdin`
2. Parsed JSON wordt als prop doorgegeven aan `<App input={data} />`
3. `App.tsx` verdeelt data naar child components
4. `GitSegment` en `UsageSegment` doen hun eigen async werk:
   - Git: voert `git` commands uit via `Bun.spawn()`
   - Usage: checkt cache (~/.claude/statusline_usage_cache.json), fetcht API indien nodig
5. Ink rendert alles naar terminal met ANSI codes

## Types

```typescript
interface StatuslineInput {
  model: {
    display_name: string;
  };
  workspace: {
    current_dir: string;
  };
  context_window: {
    context_window_size: number;
    current_usage: {
      input_tokens: number;
      output_tokens: number;
      cache_creation_input_tokens: number;
      cache_read_input_tokens: number;
    };
    total_input_tokens?: number;
  };
  cost: {
    total_lines_added: number;
    total_lines_removed: number;
    total_duration_ms: number;
  };
}
```

## Utilities

### git.ts
- Parallel uitvoeren van git commands voor snelheid
- `Bun.spawn()` voor process execution

### oauth.ts
- Eerst macOS Keychain proberen (`security find-generic-password`)
- Fallback naar `~/.claude/.credentials.json`

### Caching
- API usage cache: `~/.claude/statusline_usage_cache.json`
- TTL: 60 seconden

## Package.json

```json
{
  "name": "statusline-tim",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "start": "bun run src/index.tsx",
    "build": "bun build src/index.tsx --outdir dist --target node",
    "example": "cat example.json | bun run src/index.tsx"
  },
  "dependencies": {
    "ink": "^5.0.1",
    "react": "^18.3.1"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "@types/react": "^18.3.1",
    "typescript": "^5.0.0"
  }
}
```

## Configuratie

Claude Code settings (`~/.claude/settings.json`):

```json
{
  "statusline": {
    "command": "bun run /pad/naar/statusline-tim/src/index.tsx"
  }
}
```
