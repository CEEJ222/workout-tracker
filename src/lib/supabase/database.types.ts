export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      exercises: {
        Row: {
          auto_load: boolean
          cues: string[]
          description: string | null
          id: string
          increment_lb: number | null
          log_type: Database["public"]["Enums"]["log_type"]
          name: string
        }
        Insert: {
          auto_load?: boolean
          cues?: string[]
          description?: string | null
          id?: string
          increment_lb?: number | null
          log_type: Database["public"]["Enums"]["log_type"]
          name: string
        }
        Update: {
          auto_load?: boolean
          cues?: string[]
          description?: string | null
          id?: string
          increment_lb?: number | null
          log_type?: Database["public"]["Enums"]["log_type"]
          name?: string
        }
        Relationships: []
      }
      session_exercises: {
        Row: {
          done: boolean
          id: string
          note: string | null
          pain_severity: Database["public"]["Enums"]["pain_severity"] | null
          session_id: string
          template_exercise_id: string
        }
        Insert: {
          done?: boolean
          id?: string
          note?: string | null
          pain_severity?: Database["public"]["Enums"]["pain_severity"] | null
          session_id: string
          template_exercise_id: string
        }
        Update: {
          done?: boolean
          id?: string
          note?: string | null
          pain_severity?: Database["public"]["Enums"]["pain_severity"] | null
          session_id?: string
          template_exercise_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "session_exercises_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "session_exercises_template_exercise_id_fkey"
            columns: ["template_exercise_id"]
            isOneToOne: false
            referencedRelation: "template_exercises"
            referencedColumns: ["id"]
          },
        ]
      }
      session_sets: {
        Row: {
          actual_reps: number | null
          actual_weight: number | null
          done: boolean
          id: string
          session_exercise_id: string
          set_number: number
          target_reps_high: number
          target_reps_low: number
        }
        Insert: {
          actual_reps?: number | null
          actual_weight?: number | null
          done?: boolean
          id?: string
          session_exercise_id: string
          set_number: number
          target_reps_high: number
          target_reps_low: number
        }
        Update: {
          actual_reps?: number | null
          actual_weight?: number | null
          done?: boolean
          id?: string
          session_exercise_id?: string
          set_number?: number
          target_reps_high?: number
          target_reps_low?: number
        }
        Relationships: [
          {
            foreignKeyName: "session_sets_session_exercise_id_fkey"
            columns: ["session_exercise_id"]
            isOneToOne: false
            referencedRelation: "session_exercises"
            referencedColumns: ["id"]
          },
        ]
      }
      sessions: {
        Row: {
          completed_at: string | null
          id: string
          started_at: string
          status: Database["public"]["Enums"]["session_status"]
          template_id: string
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          id?: string
          started_at?: string
          status?: Database["public"]["Enums"]["session_status"]
          template_id: string
          user_id: string
        }
        Update: {
          completed_at?: string | null
          id?: string
          started_at?: string
          status?: Database["public"]["Enums"]["session_status"]
          template_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "sessions_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "workout_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      template_blocks: {
        Row: {
          id: string
          label: string
          sort_order: number
          template_id: string
          type: Database["public"]["Enums"]["block_type"]
        }
        Insert: {
          id?: string
          label: string
          sort_order?: number
          template_id: string
          type: Database["public"]["Enums"]["block_type"]
        }
        Update: {
          id?: string
          label?: string
          sort_order?: number
          template_id?: string
          type?: Database["public"]["Enums"]["block_type"]
        }
        Relationships: [
          {
            foreignKeyName: "template_blocks_template_id_fkey"
            columns: ["template_id"]
            isOneToOne: false
            referencedRelation: "workout_templates"
            referencedColumns: ["id"]
          },
        ]
      }
      template_exercises: {
        Row: {
          block_id: string
          exercise_id: string
          id: string
          pair_label: string | null
          per_side: boolean
          seed_is_estimate: boolean
          seed_weight: number | null
          sort_order: number
          target_reps_high: number
          target_reps_low: number
          target_sets: number
        }
        Insert: {
          block_id: string
          exercise_id: string
          id?: string
          pair_label?: string | null
          per_side?: boolean
          seed_is_estimate?: boolean
          seed_weight?: number | null
          sort_order?: number
          target_reps_high: number
          target_reps_low: number
          target_sets: number
        }
        Update: {
          block_id?: string
          exercise_id?: string
          id?: string
          pair_label?: string | null
          per_side?: boolean
          seed_is_estimate?: boolean
          seed_weight?: number | null
          sort_order?: number
          target_reps_high?: number
          target_reps_low?: number
          target_sets?: number
        }
        Relationships: [
          {
            foreignKeyName: "template_exercises_block_id_fkey"
            columns: ["block_id"]
            isOneToOne: false
            referencedRelation: "template_blocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "template_exercises_exercise_id_fkey"
            columns: ["exercise_id"]
            isOneToOne: false
            referencedRelation: "exercises"
            referencedColumns: ["id"]
          },
        ]
      }
      user_exercise_progress: {
        Row: {
          current_weight: number | null
          exercise_id: string
          is_estimate: boolean
          last_pain_severity:
            | Database["public"]["Enums"]["pain_severity"]
            | null
          updated_at: string
          user_id: string
        }
        Insert: {
          current_weight?: number | null
          exercise_id: string
          is_estimate?: boolean
          last_pain_severity?:
            | Database["public"]["Enums"]["pain_severity"]
            | null
          updated_at?: string
          user_id: string
        }
        Update: {
          current_weight?: number | null
          exercise_id?: string
          is_estimate?: boolean
          last_pain_severity?:
            | Database["public"]["Enums"]["pain_severity"]
            | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_exercise_progress_exercise_id_fkey"
            columns: ["exercise_id"]
            isOneToOne: false
            referencedRelation: "exercises"
            referencedColumns: ["id"]
          },
        ]
      }
      workout_templates: {
        Row: {
          id: string
          name: string
          sort_order: number
        }
        Insert: {
          id?: string
          name: string
          sort_order?: number
        }
        Update: {
          id?: string
          name?: string
          sort_order?: number
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      start_session: { Args: { p_template_id: string }; Returns: string }
    }
    Enums: {
      block_type: "circuit" | "superset" | "single"
      log_type: "sets_weight" | "done_check" | "done_check_weight"
      pain_severity: "mild" | "sharp"
      session_status: "in_progress" | "completed"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      block_type: ["circuit", "superset", "single"],
      log_type: ["sets_weight", "done_check", "done_check_weight"],
      pain_severity: ["mild", "sharp"],
      session_status: ["in_progress", "completed"],
    },
  },
} as const
