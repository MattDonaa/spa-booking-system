/**
 * Generated Supabase database types.
 *
 * This is a foundation placeholder. Once the schema is created (Milestone 2),
 * regenerate this file with:
 *
 *   npx supabase gen types typescript --project-id <ref> > src/lib/supabase/types.ts
 *
 * Keeping the `Database` type available now lets the Supabase clients be fully
 * typed from the start.
 */
export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export interface Database {
  public: {
    Tables: Record<string, never>;
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
