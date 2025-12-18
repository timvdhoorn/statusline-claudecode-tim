// src/types.ts
export interface StatuslineInput {
  model: {
    display_name: string;
  };
  workspace: {
    current_dir: string;
  };
  context_window: {
    context_window_size: number;
    current_usage?: {
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

export interface GitInfo {
  branch: string;
  status: 'clean' | 'dirty' | 'conflict';
  ahead: number;
  behind: number;
  lastCommitTimestamp: number | null;
}

export interface UsageData {
  fiveHourPct: number;
  resetsAt: string;
}
