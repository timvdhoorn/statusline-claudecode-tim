// src/index.tsx
import { render } from 'ink';
import { App } from './App';
import type { StatuslineInput } from './types';

async function main() {
  // Read JSON from stdin
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk as Buffer);
  }
  const inputText = Buffer.concat(chunks).toString('utf-8');

  // Parse JSON
  let input: StatuslineInput;
  try {
    input = JSON.parse(inputText);
  } catch (error) {
    console.error('Invalid JSON input');
    process.exit(1);
  }

  // Render the statusline
  const { waitUntilExit } = render(<App input={input} />);
  await waitUntilExit();
}

main().catch(console.error);
