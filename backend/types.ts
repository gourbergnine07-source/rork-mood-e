/* eslint-disable */
// AUTO-GENERATED — DO NOT EDIT
// Run migrations to regenerate.

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
      app_events: {
        Row: {
          anon_id: string
          created_at: string
          event: string
          id: string
          meta: Json
        }
        Insert: {
          anon_id: string
          created_at?: string
          event: string
          id?: string
          meta?: Json
        }
        Update: {
          anon_id?: string
          created_at?: string
          event?: string
          id?: string
          meta?: Json
        }
        Relationships: []
      }
      challenge_duos: {
        Row: {
          code: string
          created_at: string
          expires_at: string
          guest_joined: boolean
          guest_progress: number
          host_progress: number
          month_key: string
        }
        Insert: {
          code: string
          created_at?: string
          expires_at?: string
          guest_joined?: boolean
          guest_progress?: number
          host_progress?: number
          month_key: string
        }
        Update: {
          code?: string
          created_at?: string
          expires_at?: string
          guest_joined?: boolean
          guest_progress?: number
          host_progress?: number
          month_key?: string
        }
        Relationships: []
      }
      diary_check_ins: {
        Row: {
          date: string
          era_raw: string
          goal_raw: string
          id: string
          is_quick_pick: boolean
          mood_raw: string
          note: string | null
          proposed: Json
          updated_at: string | null
          user_id: string
        }
        Insert: {
          date: string
          era_raw: string
          goal_raw: string
          id: string
          is_quick_pick?: boolean
          mood_raw: string
          note?: string | null
          proposed?: Json
          updated_at?: string | null
          user_id: string
        }
        Update: {
          date?: string
          era_raw?: string
          goal_raw?: string
          id?: string
          is_quick_pick?: boolean
          mood_raw?: string
          note?: string | null
          proposed?: Json
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "diary_check_ins_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      duo_sessions: {
        Row: {
          code: string
          created_at: string
          expires_at: string
          guest_goal: string | null
          guest_joined: boolean
          guest_mood: string | null
          host_goal: string | null
          host_mood: string | null
        }
        Insert: {
          code: string
          created_at?: string
          expires_at?: string
          guest_goal?: string | null
          guest_joined?: boolean
          guest_mood?: string | null
          host_goal?: string | null
          host_mood?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          expires_at?: string
          guest_goal?: string | null
          guest_joined?: boolean
          guest_mood?: string | null
          host_goal?: string | null
          host_mood?: string | null
        }
        Relationships: []
      }
      friend_stats: {
        Row: {
          avatar: string | null
          best_streak: number
          display_name: string
          friend_code: string
          streak: number
          top_decade: number | null
          top_genre_id: number | null
          total_minutes: number
          updated_at: string
          user_id: string
          watched_count: number
        }
        Insert: {
          avatar?: string | null
          best_streak?: number
          display_name?: string
          friend_code?: string
          streak?: number
          top_decade?: number | null
          top_genre_id?: number | null
          total_minutes?: number
          updated_at?: string
          user_id: string
          watched_count?: number
        }
        Update: {
          avatar?: string | null
          best_streak?: number
          display_name?: string
          friend_code?: string
          streak?: number
          top_decade?: number | null
          top_genre_id?: number | null
          total_minutes?: number
          updated_at?: string
          user_id?: string
          watched_count?: number
        }
        Relationships: []
      }
      friends: {
        Row: {
          created_at: string
          friend_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          friend_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          friend_id?: string
          user_id?: string
        }
        Relationships: []
      }
      library_entries: {
        Row: {
          added_date: string
          movie_id: number
          poster_path: string | null
          status: string
          title: string
          updated_at: string | null
          user_id: string
          watched_date: string | null
        }
        Insert: {
          added_date: string
          movie_id: number
          poster_path?: string | null
          status: string
          title: string
          updated_at?: string | null
          user_id: string
          watched_date?: string | null
        }
        Update: {
          added_date?: string
          movie_id?: number
          poster_path?: string | null
          status?: string
          title?: string
          updated_at?: string | null
          user_id?: string
          watched_date?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "library_entries_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      planner_memories: {
        Row: {
          comment: string | null
          genre_ids: Json | null
          id: string
          movie_id: number
          poster_path: string | null
          rating: number
          title: string
          updated_at: string | null
          user_id: string
          watched_date: string
        }
        Insert: {
          comment?: string | null
          genre_ids?: Json | null
          id: string
          movie_id: number
          poster_path?: string | null
          rating?: number
          title: string
          updated_at?: string | null
          user_id: string
          watched_date: string
        }
        Update: {
          comment?: string | null
          genre_ids?: Json | null
          id?: string
          movie_id?: number
          poster_path?: string | null
          rating?: number
          title?: string
          updated_at?: string | null
          user_id?: string
          watched_date?: string
        }
        Relationships: [
          {
            foreignKeyName: "planner_memories_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      planner_scheduled: {
        Row: {
          day: string
          genre_ids: Json | null
          id: string
          movie_id: number
          poster_path: string | null
          title: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          day: string
          genre_ids?: Json | null
          id: string
          movie_id: number
          poster_path?: string | null
          title: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          day?: string
          genre_ids?: Json | null
          id?: string
          movie_id?: number
          poster_path?: string | null
          title?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "planner_scheduled_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string | null
          email: string | null
          id: string
          name: string | null
          updated_at: string | null
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string | null
          email?: string | null
          id: string
          name?: string | null
          updated_at?: string | null
        }
        Update: {
          avatar_url?: string | null
          created_at?: string | null
          email?: string | null
          id?: string
          name?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      app_events_daily: {
        Row: {
          day: string | null
          event: string | null
          total: number | null
        }
        Relationships: []
      }
    }
    Functions: {
      add_friend_by_code: {
        Args: { code: string }
        Returns: {
          friend_name: string
          friend_user_id: string
        }[]
      }
      user_id: { Args: never; Returns: string }
    }
    Enums: {
      [_ in never]: never
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
    Enums: {},
  },
} as const
