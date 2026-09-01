export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      agent_backend_operating_policies: {
        Row: {
          active: boolean
          configuration: Json
          created_at: string
          id: string
          is_current: boolean
          maximum_concurrent_operational_workers: number
          policy_key: string
          superseded_at: string | null
          version: number
          watchdog_interval: string
        }
        Insert: {
          active?: boolean
          configuration?: Json
          created_at?: string
          id?: string
          is_current?: boolean
          maximum_concurrent_operational_workers: number
          policy_key: string
          superseded_at?: string | null
          version: number
          watchdog_interval: string
        }
        Update: {
          active?: boolean
          configuration?: Json
          created_at?: string
          id?: string
          is_current?: boolean
          maximum_concurrent_operational_workers?: number
          policy_key?: string
          superseded_at?: string | null
          version?: number
          watchdog_interval?: string
        }
        Relationships: []
      }
      agent_job_runtime_policies: {
        Row: {
          active: boolean
          configuration: Json
          created_at: string
          created_by_actor_id: string | null
          exhaustion_status: string
          id: string
          is_current: boolean
          job_type: string
          lease_seconds: number | null
          maximum_attempts: number | null
          permanent_failure_categories: string[]
          permanent_failure_status: string
          policy_key: string
          retry_delay_seconds: number[]
          retryable_failure_categories: string[]
          superseded_at: string | null
          version: number
        }
        Insert: {
          active?: boolean
          configuration?: Json
          created_at?: string
          created_by_actor_id?: string | null
          exhaustion_status?: string
          id?: string
          is_current?: boolean
          job_type: string
          lease_seconds?: number | null
          maximum_attempts?: number | null
          permanent_failure_categories?: string[]
          permanent_failure_status?: string
          policy_key: string
          retry_delay_seconds?: number[]
          retryable_failure_categories?: string[]
          superseded_at?: string | null
          version: number
        }
        Update: {
          active?: boolean
          configuration?: Json
          created_at?: string
          created_by_actor_id?: string | null
          exhaustion_status?: string
          id?: string
          is_current?: boolean
          job_type?: string
          lease_seconds?: number | null
          maximum_attempts?: number | null
          permanent_failure_categories?: string[]
          permanent_failure_status?: string
          policy_key?: string
          retry_delay_seconds?: number[]
          retryable_failure_categories?: string[]
          superseded_at?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "agent_job_runtime_policies_created_by_actor_id_fkey"
            columns: ["created_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      agent_specialist_results: {
        Row: {
          data_type: string
          evidence_snapshot: Json
          expected_authoritative_version_id: string | null
          id: string
          job_type: string
          originating_job_id: string | null
          provenance_summary: string | null
          result_kind: string
          result_payload: Json
          result_schema_version: number
          subject_id: string
          subject_reference: Json
          subject_type: string
          submitted_at: string
          submitted_by_actor_id: string
        }
        Insert: {
          data_type: string
          evidence_snapshot?: Json
          expected_authoritative_version_id?: string | null
          id?: string
          job_type: string
          originating_job_id?: string | null
          provenance_summary?: string | null
          result_kind: string
          result_payload: Json
          result_schema_version?: number
          subject_id: string
          subject_reference?: Json
          subject_type: string
          submitted_at?: string
          submitted_by_actor_id: string
        }
        Update: {
          data_type?: string
          evidence_snapshot?: Json
          expected_authoritative_version_id?: string | null
          id?: string
          job_type?: string
          originating_job_id?: string | null
          provenance_summary?: string | null
          result_kind?: string
          result_payload?: Json
          result_schema_version?: number
          subject_id?: string
          subject_reference?: Json
          subject_type?: string
          submitted_at?: string
          submitted_by_actor_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "agent_specialist_results_submitted_by_actor_id_fkey"
            columns: ["submitted_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      agent_work_wake_outbox: {
        Row: {
          acknowledged_at: string | null
          acknowledged_by_actor_id: string | null
          available_at: string
          created_at: string
          eligibility_key: string
          event_kind: string
          id: string
          queue_name: string
          status: string
          work_item_id: string
        }
        Insert: {
          acknowledged_at?: string | null
          acknowledged_by_actor_id?: string | null
          available_at: string
          created_at?: string
          eligibility_key: string
          event_kind: string
          id?: string
          queue_name: string
          status?: string
          work_item_id: string
        }
        Update: {
          acknowledged_at?: string | null
          acknowledged_by_actor_id?: string | null
          available_at?: string
          created_at?: string
          eligibility_key?: string
          event_kind?: string
          id?: string
          queue_name?: string
          status?: string
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "agent_work_wake_outbox_acknowledged_by_actor_id_fkey"
            columns: ["acknowledged_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      agent_worker_pool_concurrency_policies: {
        Row: {
          created_at: string
          id: string
          maximum_concurrent_workers: number
          operating_policy_id: string
          worker_pool: string
        }
        Insert: {
          created_at?: string
          id?: string
          maximum_concurrent_workers: number
          operating_policy_id: string
          worker_pool: string
        }
        Update: {
          created_at?: string
          id?: string
          maximum_concurrent_workers?: number
          operating_policy_id?: string
          worker_pool?: string
        }
        Relationships: [
          {
            foreignKeyName: "agent_worker_pool_concurrency_policies_operating_policy_id_fkey"
            columns: ["operating_policy_id"]
            isOneToOne: false
            referencedRelation: "agent_backend_operating_policies"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_actor_capabilities: {
        Row: {
          active: boolean
          actor_id: string
          capability: string
          created_at: string
          granted_by: string | null
          id: string
          league_id: string | null
          sport_id: string | null
          team_id: string | null
          venue_id: string | null
        }
        Insert: {
          active?: boolean
          actor_id: string
          capability: string
          created_at?: string
          granted_by?: string | null
          id?: string
          league_id?: string | null
          sport_id?: string | null
          team_id?: string | null
          venue_id?: string | null
        }
        Update: {
          active?: boolean
          actor_id?: string
          capability?: string
          created_at?: string
          granted_by?: string | null
          id?: string
          league_id?: string | null
          sport_id?: string | null
          team_id?: string | null
          venue_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "catalog_actor_capabilities_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_actor_capabilities_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "catalog_leagues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_actor_capabilities_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_actor_capabilities_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_actor_capabilities_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "catalog_actor_capabilities_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "catalog_actor_capabilities_venue_fk"
            columns: ["venue_id"]
            isOneToOne: false
            referencedRelation: "catalog_venues"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_actors: {
        Row: {
          active: boolean
          actor_key: string
          actor_type: string
          auth_user_id: string | null
          created_at: string
          display_name: string
          id: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          actor_key: string
          actor_type: string
          auth_user_id?: string | null
          created_at?: string
          display_name: string
          id?: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          actor_key?: string
          actor_type?: string
          auth_user_id?: string | null
          created_at?: string
          display_name?: string
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      catalog_adjudication_source_contributions: {
        Row: {
          adjudication_id: string
          contribution_role: string
          created_at: string
          evidence_id: string
          evidence_kind: string
          id: string
          information_lineage_root_id: string | null
          information_lineage_version_id: string | null
          source_id: string
          supports_authoritative_result: boolean
        }
        Insert: {
          adjudication_id: string
          contribution_role: string
          created_at?: string
          evidence_id: string
          evidence_kind: string
          id?: string
          information_lineage_root_id?: string | null
          information_lineage_version_id?: string | null
          source_id: string
          supports_authoritative_result: boolean
        }
        Update: {
          adjudication_id?: string
          contribution_role?: string
          created_at?: string
          evidence_id?: string
          evidence_kind?: string
          id?: string
          information_lineage_root_id?: string | null
          information_lineage_version_id?: string | null
          source_id?: string
          supports_authoritative_result?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "catalog_adjudication_source_c_information_lineage_version__fkey"
            columns: ["information_lineage_version_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_adjudication_source_co_information_lineage_root_id_fkey"
            columns: ["information_lineage_root_id"]
            isOneToOne: false
            referencedRelation: "information_lineages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_adjudication_source_contributions_adjudication_id_fkey"
            columns: ["adjudication_id"]
            isOneToOne: false
            referencedRelation: "catalog_determinate_adjudications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_adjudication_source_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_adjudication_source_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_adjudication_source_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_adjudication_source_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_adjudication_source_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_audit_events: {
        Row: {
          action: string
          actor_id: string | null
          auth_user_id: string | null
          details: Json
          entity_id: string | null
          entity_type: string
          id: number
          occurred_at: string
          proposal_id: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          auth_user_id?: string | null
          details?: Json
          entity_id?: string | null
          entity_type: string
          id?: never
          occurred_at?: string
          proposal_id?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          auth_user_id?: string | null
          details?: Json
          entity_id?: string | null
          entity_type?: string
          id?: never
          occurred_at?: string
          proposal_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "catalog_audit_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_audit_events_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "catalog_change_proposals"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_change_proposals: {
        Row: {
          expected_current_color_version_id: string | null
          fact_type: string
          id: string
          operation: string
          payload: Json
          proposal_reason: string | null
          proposed_by_actor_id: string
          proposed_public_id: string | null
          recheck_trigger: string | null
          resolution_notes: string | null
          resolved_at: string | null
          status: string
          submitted_at: string
          target_league_id: string | null
          target_team_id: string | null
          target_venue_id: string | null
          team_color_change_kind: string | null
          team_color_work_item_id: string | null
        }
        Insert: {
          expected_current_color_version_id?: string | null
          fact_type: string
          id?: string
          operation?: string
          payload: Json
          proposal_reason?: string | null
          proposed_by_actor_id: string
          proposed_public_id?: string | null
          recheck_trigger?: string | null
          resolution_notes?: string | null
          resolved_at?: string | null
          status?: string
          submitted_at?: string
          target_league_id?: string | null
          target_team_id?: string | null
          target_venue_id?: string | null
          team_color_change_kind?: string | null
          team_color_work_item_id?: string | null
        }
        Update: {
          expected_current_color_version_id?: string | null
          fact_type?: string
          id?: string
          operation?: string
          payload?: Json
          proposal_reason?: string | null
          proposed_by_actor_id?: string
          proposed_public_id?: string | null
          recheck_trigger?: string | null
          resolution_notes?: string | null
          resolved_at?: string | null
          status?: string
          submitted_at?: string
          target_league_id?: string | null
          target_team_id?: string | null
          target_venue_id?: string | null
          team_color_change_kind?: string | null
          team_color_work_item_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "catalog_change_proposals_expected_current_color_version_id_fkey"
            columns: ["expected_current_color_version_id"]
            isOneToOne: false
            referencedRelation: "team_color_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_change_proposals_proposed_by_actor_id_fkey"
            columns: ["proposed_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_change_proposals_target_league_id_fkey"
            columns: ["target_league_id"]
            isOneToOne: false
            referencedRelation: "catalog_leagues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_change_proposals_target_team_id_fkey"
            columns: ["target_team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_change_proposals_target_team_id_fkey"
            columns: ["target_team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "catalog_change_proposals_target_team_id_fkey"
            columns: ["target_team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "catalog_change_proposals_target_venue_id_fkey"
            columns: ["target_venue_id"]
            isOneToOne: false
            referencedRelation: "catalog_venues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_change_proposals_team_color_work_item_id_fkey"
            columns: ["team_color_work_item_id"]
            isOneToOne: false
            referencedRelation: "team_color_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_competition_edition_identifiers: {
        Row: {
          competition_edition_id: string
          created_at: string
          id: string
          identifier: string
          import_batch_id: string | null
          namespace: string
          record_status: string
          verification_decision_id: string | null
        }
        Insert: {
          competition_edition_id: string
          created_at?: string
          id?: string
          identifier: string
          import_batch_id?: string | null
          namespace: string
          record_status?: string
          verification_decision_id?: string | null
        }
        Update: {
          competition_edition_id?: string
          created_at?: string
          id?: string
          identifier?: string
          import_batch_id?: string | null
          namespace?: string
          record_status?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "catalog_competition_edition_ident_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_competition_edition_identif_competition_edition_id_fkey"
            columns: ["competition_edition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_competition_edition_identif_competition_edition_id_fkey"
            columns: ["competition_edition_id"]
            isOneToOne: false
            referencedRelation: "competition_edition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "catalog_competition_edition_identifiers_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_competition_editions: {
        Row: {
          competition_id: string
          created_at: string
          edition_id: string
          id: string
          updated_at: string
        }
        Insert: {
          competition_id: string
          created_at?: string
          edition_id: string
          id?: string
          updated_at?: string
        }
        Update: {
          competition_id?: string
          created_at?: string
          edition_id?: string
          id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_competition_editions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_competition_editions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      catalog_competition_filter_groups: {
        Row: {
          created_at: string
          filter_group_id: string
          id: string
          sport_id: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          filter_group_id: string
          id?: string
          sport_id?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          filter_group_id?: string
          id?: string
          sport_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_competition_filter_groups_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_competition_identifiers: {
        Row: {
          competition_id: string
          created_at: string
          id: string
          identifier: string
          import_batch_id: string | null
          namespace: string
          record_status: string
          verification_decision_id: string | null
        }
        Insert: {
          competition_id: string
          created_at?: string
          id?: string
          identifier: string
          import_batch_id?: string | null
          namespace: string
          record_status?: string
          verification_decision_id?: string | null
        }
        Update: {
          competition_id?: string
          created_at?: string
          id?: string
          identifier?: string
          import_batch_id?: string | null
          namespace?: string
          record_status?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "catalog_competition_identifiers_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_competition_identifiers_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "catalog_competition_identifiers_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_competition_identifiers_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_competitions: {
        Row: {
          competition_id: string
          created_at: string
          id: string
          import_batch_id: string | null
          kind_id: string
          sport_id: string
          updated_at: string
        }
        Insert: {
          competition_id: string
          created_at?: string
          id?: string
          import_batch_id?: string | null
          kind_id: string
          sport_id: string
          updated_at?: string
        }
        Update: {
          competition_id?: string
          created_at?: string
          id?: string
          import_batch_id?: string | null
          kind_id?: string
          sport_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_competitions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_competitions_kind_id_fkey"
            columns: ["kind_id"]
            isOneToOne: false
            referencedRelation: "competition_kinds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_competitions_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_determinate_adjudications: {
        Row: {
          authoritative_result_payload: Json | null
          catalog_verification_decision_id: string | null
          data_type: string
          decided_at: string
          decided_by_actor_id: string
          id: string
          outcome: string
          resolution_snapshot: Json
          resolving_verifier_result_id: string
          specialist_result_id: string
          specialist_result_kind: string
          subject_id: string
          subject_type: string
          verification_policy_id: string
        }
        Insert: {
          authoritative_result_payload?: Json | null
          catalog_verification_decision_id?: string | null
          data_type: string
          decided_at?: string
          decided_by_actor_id: string
          id?: string
          outcome: string
          resolution_snapshot?: Json
          resolving_verifier_result_id: string
          specialist_result_id: string
          specialist_result_kind: string
          subject_id: string
          subject_type: string
          verification_policy_id: string
        }
        Update: {
          authoritative_result_payload?: Json | null
          catalog_verification_decision_id?: string | null
          data_type?: string
          decided_at?: string
          decided_by_actor_id?: string
          id?: string
          outcome?: string
          resolution_snapshot?: Json
          resolving_verifier_result_id?: string
          specialist_result_id?: string
          specialist_result_kind?: string
          subject_id?: string
          subject_type?: string
          verification_policy_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_determinate_adjudicat_catalog_verification_decisio_fkey"
            columns: ["catalog_verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_determinate_adjudicat_resolving_verifier_result_id_fkey"
            columns: ["resolving_verifier_result_id"]
            isOneToOne: false
            referencedRelation: "catalog_verifier_results"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_determinate_adjudications_decided_by_actor_id_fkey"
            columns: ["decided_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_determinate_adjudications_verification_policy_id_fkey"
            columns: ["verification_policy_id"]
            isOneToOne: false
            referencedRelation: "verification_policies"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_domain_adapters: {
        Row: {
          active: boolean
          build_source_qualification_context_function: unknown
          build_verifier_context_function: unknown
          compare_result_function: unknown
          compare_source_qualification_result_function: unknown
          configuration: Json
          created_at: string
          data_type: string
          enqueue_revalidation_function: unknown
          finalize_authoritative_function: unknown
          normalize_source_qualification_result_function: unknown
          reconcile_wakes_function: unknown
          record_adjudication_source_contributions_function: unknown
          recover_domain_function: unknown
          resolve_source_qualification_reference_function: unknown
          specialist_job_type: string | null
          subject_type: string
          updated_at: string
          verification_capability: string
          verification_job_type: string
        }
        Insert: {
          active?: boolean
          build_source_qualification_context_function?: unknown
          build_verifier_context_function: unknown
          compare_result_function: unknown
          compare_source_qualification_result_function?: unknown
          configuration?: Json
          created_at?: string
          data_type: string
          enqueue_revalidation_function?: unknown
          finalize_authoritative_function: unknown
          normalize_source_qualification_result_function?: unknown
          reconcile_wakes_function?: unknown
          record_adjudication_source_contributions_function?: unknown
          recover_domain_function?: unknown
          resolve_source_qualification_reference_function?: unknown
          specialist_job_type?: string | null
          subject_type: string
          updated_at?: string
          verification_capability: string
          verification_job_type: string
        }
        Update: {
          active?: boolean
          build_source_qualification_context_function?: unknown
          build_verifier_context_function?: unknown
          compare_result_function?: unknown
          compare_source_qualification_result_function?: unknown
          configuration?: Json
          created_at?: string
          data_type?: string
          enqueue_revalidation_function?: unknown
          finalize_authoritative_function?: unknown
          normalize_source_qualification_result_function?: unknown
          reconcile_wakes_function?: unknown
          record_adjudication_source_contributions_function?: unknown
          recover_domain_function?: unknown
          resolve_source_qualification_reference_function?: unknown
          specialist_job_type?: string | null
          subject_type?: string
          updated_at?: string
          verification_capability?: string
          verification_job_type?: string
        }
        Relationships: []
      }
      catalog_evidence_lineage_assignments: {
        Row: {
          assigned_by_actor_id: string | null
          assignment_basis: string
          created_at: string
          evidence_id: string
          evidence_kind: string
          id: string
          information_lineage_version_id: string
          is_current: boolean
          resolution_result_id: string | null
          superseded_at: string | null
        }
        Insert: {
          assigned_by_actor_id?: string | null
          assignment_basis: string
          created_at?: string
          evidence_id: string
          evidence_kind: string
          id?: string
          information_lineage_version_id: string
          is_current?: boolean
          resolution_result_id?: string | null
          superseded_at?: string | null
        }
        Update: {
          assigned_by_actor_id?: string | null
          assignment_basis?: string
          created_at?: string
          evidence_id?: string
          evidence_kind?: string
          id?: string
          information_lineage_version_id?: string
          is_current?: boolean
          resolution_result_id?: string | null
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "catalog_evidence_lineage_assi_information_lineage_version__fkey"
            columns: ["information_lineage_version_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_evidence_lineage_assignments_assigned_by_actor_id_fkey"
            columns: ["assigned_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_evidence_lineage_assignments_resolution_result_id_fkey"
            columns: ["resolution_result_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_resolution_results"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_fact_revalidation_state: {
        Row: {
          active_job_id: string | null
          active_job_type: string | null
          cadence_policy_id: string | null
          current_fact_version_id: string
          data_type: string
          id: string
          last_review_outcome: string | null
          last_review_reason: string | null
          last_review_trigger: string | null
          last_verification_decision_id: string | null
          last_verified_at: string
          next_review_at: string | null
          subject_id: string
          subject_reference: Json
          subject_type: string
          updated_at: string
        }
        Insert: {
          active_job_id?: string | null
          active_job_type?: string | null
          cadence_policy_id?: string | null
          current_fact_version_id: string
          data_type: string
          id?: string
          last_review_outcome?: string | null
          last_review_reason?: string | null
          last_review_trigger?: string | null
          last_verification_decision_id?: string | null
          last_verified_at: string
          next_review_at?: string | null
          subject_id: string
          subject_reference?: Json
          subject_type: string
          updated_at?: string
        }
        Update: {
          active_job_id?: string | null
          active_job_type?: string | null
          cadence_policy_id?: string | null
          current_fact_version_id?: string
          data_type?: string
          id?: string
          last_review_outcome?: string | null
          last_review_reason?: string | null
          last_review_trigger?: string | null
          last_verification_decision_id?: string | null
          last_verified_at?: string
          next_review_at?: string | null
          subject_id?: string
          subject_reference?: Json
          subject_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_fact_revalidation_sta_last_verification_decision_i_fkey"
            columns: ["last_verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_fact_revalidation_state_cadence_policy_id_fkey"
            columns: ["cadence_policy_id"]
            isOneToOne: false
            referencedRelation: "catalog_revalidation_policies"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_import_batches: {
        Row: {
          id: string
          import_key: string
          imported_at: string
          notes: string | null
          record_counts: Json
          source_filename: string
          source_kind: string
          source_sha256: string
          verified_source_data: boolean
        }
        Insert: {
          id?: string
          import_key: string
          imported_at?: string
          notes?: string | null
          record_counts?: Json
          source_filename: string
          source_kind: string
          source_sha256: string
          verified_source_data?: boolean
        }
        Update: {
          id?: string
          import_key?: string
          imported_at?: string
          notes?: string | null
          record_counts?: Json
          source_filename?: string
          source_kind?: string
          source_sha256?: string
          verified_source_data?: boolean
        }
        Relationships: []
      }
      catalog_league_competition_mappings: {
        Row: {
          competition_id: string
          created_at: string
          league_id: string
        }
        Insert: {
          competition_id: string
          created_at?: string
          league_id: string
        }
        Update: {
          competition_id?: string
          created_at?: string
          league_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_league_competition_mappings_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: true
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_league_competition_mappings_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: true
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "catalog_league_competition_mappings_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: true
            referencedRelation: "catalog_leagues"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_league_identifiers: {
        Row: {
          created_at: string
          id: string
          identifier: string
          league_id: string
          namespace: string
        }
        Insert: {
          created_at?: string
          id?: string
          identifier: string
          league_id: string
          namespace: string
        }
        Update: {
          created_at?: string
          id?: string
          identifier?: string
          league_id?: string
          namespace?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_league_identifiers_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "catalog_leagues"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_leagues: {
        Row: {
          active: boolean
          country_region: string | null
          created_at: string
          display_name: string
          id: string
          import_batch_id: string | null
          league_id: string
          primary_languages: string[]
          seed_status: string
          short_name: string | null
          sport_id: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          country_region?: string | null
          created_at?: string
          display_name: string
          id?: string
          import_batch_id?: string | null
          league_id: string
          primary_languages?: string[]
          seed_status?: string
          short_name?: string | null
          sport_id: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          country_region?: string | null
          created_at?: string
          display_name?: string
          id?: string
          import_batch_id?: string | null
          league_id?: string
          primary_languages?: string[]
          seed_status?: string
          short_name?: string | null
          sport_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_leagues_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_leagues_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_media_assets: {
        Row: {
          asset_id: string
          created_at: string
          id: string
          media_type: string | null
          metadata: Json
          rights_status: string
          source_url: string | null
          storage_bucket: string | null
          storage_path: string | null
          updated_at: string
        }
        Insert: {
          asset_id: string
          created_at?: string
          id?: string
          media_type?: string | null
          metadata?: Json
          rights_status?: string
          source_url?: string | null
          storage_bucket?: string | null
          storage_path?: string | null
          updated_at?: string
        }
        Update: {
          asset_id?: string
          created_at?: string
          id?: string
          media_type?: string | null
          metadata?: Json
          rights_status?: string
          source_url?: string | null
          storage_bucket?: string | null
          storage_path?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      catalog_people: {
        Row: {
          created_at: string
          id: string
          person_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          person_id?: string
        }
        Update: {
          created_at?: string
          id?: string
          person_id?: string
        }
        Relationships: []
      }
      catalog_proposal_evidence: {
        Row: {
          created_at: string
          evidence_summary: string | null
          evidence_url: string
          id: string
          information_lineage_basis: string | null
          information_lineage_version_id: string | null
          observed_at: string | null
          proposal_id: string
          source_applicability_version_id: string | null
          source_id: string
          source_independence_assignment_id: string | null
          source_qualification_evaluation_id: string | null
          source_qualification_snapshot: Json
          source_trust_assignment_id: string | null
          source_url_scope_version_id: string | null
          structured_claim: Json | null
          submitted_by_actor_id: string
          supports_proposal: boolean
        }
        Insert: {
          created_at?: string
          evidence_summary?: string | null
          evidence_url: string
          id?: string
          information_lineage_basis?: string | null
          information_lineage_version_id?: string | null
          observed_at?: string | null
          proposal_id: string
          source_applicability_version_id?: string | null
          source_id: string
          source_independence_assignment_id?: string | null
          source_qualification_evaluation_id?: string | null
          source_qualification_snapshot?: Json
          source_trust_assignment_id?: string | null
          source_url_scope_version_id?: string | null
          structured_claim?: Json | null
          submitted_by_actor_id: string
          supports_proposal?: boolean
        }
        Update: {
          created_at?: string
          evidence_summary?: string | null
          evidence_url?: string
          id?: string
          information_lineage_basis?: string | null
          information_lineage_version_id?: string | null
          observed_at?: string | null
          proposal_id?: string
          source_applicability_version_id?: string | null
          source_id?: string
          source_independence_assignment_id?: string | null
          source_qualification_evaluation_id?: string | null
          source_qualification_snapshot?: Json
          source_trust_assignment_id?: string | null
          source_url_scope_version_id?: string | null
          structured_claim?: Json | null
          submitted_by_actor_id?: string
          supports_proposal?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "catalog_proposal_evidence_information_lineage_version_id_fkey"
            columns: ["information_lineage_version_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "catalog_change_proposals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_applicability_version_id_fkey"
            columns: ["source_applicability_version_id"]
            isOneToOne: false
            referencedRelation: "source_applicability_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_independence_assignment_i_fkey"
            columns: ["source_independence_assignment_id"]
            isOneToOne: false
            referencedRelation: "source_independence_group_assignment_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_qualification_evaluation__fkey"
            columns: ["source_qualification_evaluation_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_evaluations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_trust_assignment_id_fkey"
            columns: ["source_trust_assignment_id"]
            isOneToOne: false
            referencedRelation: "source_trust_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_source_url_scope_version_id_fkey"
            columns: ["source_url_scope_version_id"]
            isOneToOne: false
            referencedRelation: "trusted_source_url_scope_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_proposal_evidence_submitted_by_actor_id_fkey"
            columns: ["submitted_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_revalidation_policies: {
        Row: {
          active: boolean
          configuration: Json
          created_at: string
          created_by_actor_id: string | null
          data_type: string
          id: string
          is_current: boolean
          policy_key: string
          review_cadence: string
          superseded_at: string | null
          version: number
        }
        Insert: {
          active?: boolean
          configuration?: Json
          created_at?: string
          created_by_actor_id?: string | null
          data_type: string
          id?: string
          is_current?: boolean
          policy_key: string
          review_cadence: string
          superseded_at?: string | null
          version: number
        }
        Update: {
          active?: boolean
          configuration?: Json
          created_at?: string
          created_by_actor_id?: string | null
          data_type?: string
          id?: string
          is_current?: boolean
          policy_key?: string
          review_cadence?: string
          superseded_at?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "catalog_revalidation_policies_created_by_actor_id_fkey"
            columns: ["created_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_sports: {
        Row: {
          active: boolean
          created_at: string
          display_name: string
          id: string
          sport_id: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          display_name: string
          id?: string
          sport_id: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          display_name?: string
          id?: string
          sport_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      catalog_team_id_sequences: {
        Row: {
          next_value: number
          sport_id: string
          updated_at: string
        }
        Insert: {
          next_value: number
          sport_id: string
          updated_at?: string
        }
        Update: {
          next_value?: number
          sport_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_team_id_sequences_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: true
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_team_identifiers: {
        Row: {
          created_at: string
          id: string
          identifier: string
          import_batch_id: string | null
          namespace: string
          record_status: string
          team_id: string
          verification_decision_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          identifier: string
          import_batch_id?: string | null
          namespace: string
          record_status?: string
          team_id: string
          verification_decision_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          identifier?: string
          import_batch_id?: string | null
          namespace?: string
          record_status?: string
          team_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "catalog_team_identifiers_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_team_identifiers_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_team_identifiers_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "catalog_team_identifiers_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "catalog_team_identifiers_verification_decision_fk"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_teams: {
        Row: {
          created_at: string
          id: string
          import_batch_id: string | null
          sport_id: string
          team_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          import_batch_id?: string | null
          sport_id: string
          team_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          import_batch_id?: string | null
          sport_id?: string
          team_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_teams_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_teams_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_venues: {
        Row: {
          created_at: string
          id: string
          updated_at: string
          venue_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          updated_at?: string
          venue_id: string
        }
        Update: {
          created_at?: string
          id?: string
          updated_at?: string
          venue_id?: string
        }
        Relationships: []
      }
      catalog_verification_attempts: {
        Row: {
          actor_id: string
          attempt_number: number
          claimed_at: string
          ended_at: string | null
          failure_category: string | null
          failure_reason: string | null
          id: string
          last_heartbeat_at: string
          lease_expires_at: string
          lease_token: string
          outcome: string | null
          verification_work_item_id: string
        }
        Insert: {
          actor_id: string
          attempt_number: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at: string
          lease_token: string
          outcome?: string | null
          verification_work_item_id: string
        }
        Update: {
          actor_id?: string
          attempt_number?: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at?: string
          lease_token?: string
          outcome?: string | null
          verification_work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_verification_attempts_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_attempts_verification_work_item_id_fkey"
            columns: ["verification_work_item_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_verification_comparisons: {
        Row: {
          adjudication_id: string | null
          compared_at: string
          comparison_outcome: string
          details: Json
          id: string
          normalized_specialist_result: Json | null
          normalized_verifier_result: Json | null
          policy_id: string | null
          proposal_id: string | null
          specialist_result_id: string
          specialist_result_kind: string
          verification_decision_id: string | null
          verification_round: number
          verification_work_item_id: string
          verifier_result_id: string
        }
        Insert: {
          adjudication_id?: string | null
          compared_at?: string
          comparison_outcome: string
          details?: Json
          id?: string
          normalized_specialist_result?: Json | null
          normalized_verifier_result?: Json | null
          policy_id?: string | null
          proposal_id?: string | null
          specialist_result_id: string
          specialist_result_kind: string
          verification_decision_id?: string | null
          verification_round: number
          verification_work_item_id: string
          verifier_result_id: string
        }
        Update: {
          adjudication_id?: string | null
          compared_at?: string
          comparison_outcome?: string
          details?: Json
          id?: string
          normalized_specialist_result?: Json | null
          normalized_verifier_result?: Json | null
          policy_id?: string | null
          proposal_id?: string | null
          specialist_result_id?: string
          specialist_result_kind?: string
          verification_decision_id?: string | null
          verification_round?: number
          verification_work_item_id?: string
          verifier_result_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_verification_comparisons_adjudication_id_fkey"
            columns: ["adjudication_id"]
            isOneToOne: false
            referencedRelation: "catalog_determinate_adjudications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_comparisons_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "verification_policies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_comparisons_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "catalog_change_proposals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_comparisons_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_comparisons_verification_work_item_id_fkey"
            columns: ["verification_work_item_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_work_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_comparisons_verifier_result_id_fkey"
            columns: ["verifier_result_id"]
            isOneToOne: true
            referencedRelation: "catalog_verifier_results"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_verification_decisions: {
        Row: {
          authoritative_result_payload: Json | null
          decided_at: string
          decided_by_actor_id: string
          decision: string
          evidence_snapshot: Json
          id: string
          notes: string | null
          policy_id: string | null
          policy_snapshot: Json
          proposal_id: string
          verification_resolution_snapshot: Json
        }
        Insert: {
          authoritative_result_payload?: Json | null
          decided_at?: string
          decided_by_actor_id: string
          decision: string
          evidence_snapshot?: Json
          id?: string
          notes?: string | null
          policy_id?: string | null
          policy_snapshot?: Json
          proposal_id: string
          verification_resolution_snapshot?: Json
        }
        Update: {
          authoritative_result_payload?: Json | null
          decided_at?: string
          decided_by_actor_id?: string
          decision?: string
          evidence_snapshot?: Json
          id?: string
          notes?: string | null
          policy_id?: string | null
          policy_snapshot?: Json
          proposal_id?: string
          verification_resolution_snapshot?: Json
        }
        Relationships: [
          {
            foreignKeyName: "catalog_verification_decisions_decided_by_actor_id_fkey"
            columns: ["decided_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_decisions_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "verification_policies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_decisions_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: true
            referencedRelation: "catalog_change_proposals"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_verification_round_policies: {
        Row: {
          allowed_trust_tiers: number[] | null
          created_at: string
          id: string
          minimum_evidence_count: number | null
          minimum_high_trust_evidence_count: number | null
          minimum_independent_information_lineages: number | null
          minimum_independent_ownership_groups: number | null
          source_selection_policy: Json
          verification_policy_id: string
          verification_round: number
        }
        Insert: {
          allowed_trust_tiers?: number[] | null
          created_at?: string
          id?: string
          minimum_evidence_count?: number | null
          minimum_high_trust_evidence_count?: number | null
          minimum_independent_information_lineages?: number | null
          minimum_independent_ownership_groups?: number | null
          source_selection_policy?: Json
          verification_policy_id: string
          verification_round: number
        }
        Update: {
          allowed_trust_tiers?: number[] | null
          created_at?: string
          id?: string
          minimum_evidence_count?: number | null
          minimum_high_trust_evidence_count?: number | null
          minimum_independent_information_lineages?: number | null
          minimum_independent_ownership_groups?: number | null
          source_selection_policy?: Json
          verification_policy_id?: string
          verification_round?: number
        }
        Relationships: [
          {
            foreignKeyName: "catalog_verification_round_policies_verification_policy_id_fkey"
            columns: ["verification_policy_id"]
            isOneToOne: false
            referencedRelation: "verification_policies"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_verification_work_events: {
        Row: {
          actor_id: string | null
          attempt_number: number | null
          details: Json
          event_type: string
          id: number
          occurred_at: string
          verification_work_item_id: string
        }
        Insert: {
          actor_id?: string | null
          attempt_number?: number | null
          details?: Json
          event_type: string
          id?: never
          occurred_at?: string
          verification_work_item_id: string
        }
        Update: {
          actor_id?: string | null
          attempt_number?: number | null
          details?: Json
          event_type?: string
          id?: never
          occurred_at?: string
          verification_work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_verification_work_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_work_events_verification_work_item_id_fkey"
            columns: ["verification_work_item_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_verification_work_items: {
        Row: {
          accepted_result_id: string | null
          attempt_count: number
          available_at: string
          capability_scope: Json
          claimed_by_actor_id: string | null
          completed_at: string | null
          created_at: string
          data_type: string
          expected_current_version_id: string | null
          failure_category: string | null
          failure_reason: string | null
          id: string
          lease_expires_at: string | null
          lease_token: string | null
          originating_job_id: string | null
          originating_job_type: string | null
          parent_verification_work_item_id: string | null
          priority: number
          proposal_id: string | null
          round_requirement_snapshot: Json
          specialist_result_id: string
          specialist_result_kind: string
          status: string
          subject_id: string
          subject_reference: Json
          subject_type: string
          updated_at: string
          verification_policy_id: string
          verification_round: number
          verifier_context: Json
        }
        Insert: {
          accepted_result_id?: string | null
          attempt_count?: number
          available_at?: string
          capability_scope?: Json
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          data_type: string
          expected_current_version_id?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          lease_expires_at?: string | null
          lease_token?: string | null
          originating_job_id?: string | null
          originating_job_type?: string | null
          parent_verification_work_item_id?: string | null
          priority?: number
          proposal_id?: string | null
          round_requirement_snapshot?: Json
          specialist_result_id: string
          specialist_result_kind: string
          status?: string
          subject_id: string
          subject_reference?: Json
          subject_type: string
          updated_at?: string
          verification_policy_id: string
          verification_round?: number
          verifier_context?: Json
        }
        Update: {
          accepted_result_id?: string | null
          attempt_count?: number
          available_at?: string
          capability_scope?: Json
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          data_type?: string
          expected_current_version_id?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          lease_expires_at?: string | null
          lease_token?: string | null
          originating_job_id?: string | null
          originating_job_type?: string | null
          parent_verification_work_item_id?: string | null
          priority?: number
          proposal_id?: string | null
          round_requirement_snapshot?: Json
          specialist_result_id?: string
          specialist_result_kind?: string
          status?: string
          subject_id?: string
          subject_reference?: Json
          subject_type?: string
          updated_at?: string
          verification_policy_id?: string
          verification_round?: number
          verifier_context?: Json
        }
        Relationships: [
          {
            foreignKeyName: "catalog_verification_work_ite_parent_verification_work_ite_fkey"
            columns: ["parent_verification_work_item_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_work_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_work_items_claimed_by_actor_id_fkey"
            columns: ["claimed_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_work_items_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "catalog_change_proposals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_work_items_verification_policy_id_fkey"
            columns: ["verification_policy_id"]
            isOneToOne: false
            referencedRelation: "verification_policies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verification_work_result_fk"
            columns: ["accepted_result_id"]
            isOneToOne: false
            referencedRelation: "catalog_verifier_results"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_verifier_evidence: {
        Row: {
          attempt_number: number
          created_at: string
          evidence_summary: string | null
          evidence_url: string
          id: string
          information_lineage_basis: string | null
          information_lineage_version_id: string | null
          observed_at: string | null
          source_applicability_version_id: string
          source_id: string
          source_independence_assignment_id: string
          source_qualification_evaluation_id: string | null
          source_qualification_snapshot: Json
          source_reliability_snapshot: Json
          source_trust_assignment_id: string
          source_url_scope_version_id: string
          structured_claim: Json
          submitted_by_actor_id: string
          verification_work_item_id: string
        }
        Insert: {
          attempt_number: number
          created_at?: string
          evidence_summary?: string | null
          evidence_url: string
          id?: string
          information_lineage_basis?: string | null
          information_lineage_version_id?: string | null
          observed_at?: string | null
          source_applicability_version_id: string
          source_id: string
          source_independence_assignment_id: string
          source_qualification_evaluation_id?: string | null
          source_qualification_snapshot?: Json
          source_reliability_snapshot?: Json
          source_trust_assignment_id: string
          source_url_scope_version_id: string
          structured_claim: Json
          submitted_by_actor_id: string
          verification_work_item_id: string
        }
        Update: {
          attempt_number?: number
          created_at?: string
          evidence_summary?: string | null
          evidence_url?: string
          id?: string
          information_lineage_basis?: string | null
          information_lineage_version_id?: string | null
          observed_at?: string | null
          source_applicability_version_id?: string
          source_id?: string
          source_independence_assignment_id?: string
          source_qualification_evaluation_id?: string | null
          source_qualification_snapshot?: Json
          source_reliability_snapshot?: Json
          source_trust_assignment_id?: string
          source_url_scope_version_id?: string
          structured_claim?: Json
          submitted_by_actor_id?: string
          verification_work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_verifier_evidence_information_lineage_version_id_fkey"
            columns: ["information_lineage_version_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_applicability_version_id_fkey"
            columns: ["source_applicability_version_id"]
            isOneToOne: false
            referencedRelation: "source_applicability_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_independence_assignment_i_fkey"
            columns: ["source_independence_assignment_id"]
            isOneToOne: false
            referencedRelation: "source_independence_group_assignment_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_qualification_evaluation__fkey"
            columns: ["source_qualification_evaluation_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_evaluations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_trust_assignment_id_fkey"
            columns: ["source_trust_assignment_id"]
            isOneToOne: false
            referencedRelation: "source_trust_assignments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_source_url_scope_version_id_fkey"
            columns: ["source_url_scope_version_id"]
            isOneToOne: false
            referencedRelation: "trusted_source_url_scope_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_submitted_by_actor_id_fkey"
            columns: ["submitted_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_evidence_verification_work_item_id_fkey"
            columns: ["verification_work_item_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      catalog_verifier_results: {
        Row: {
          evidence_snapshot: Json
          id: string
          provenance_summary: string | null
          result_kind: string
          result_payload: Json
          result_schema_version: number
          submitted_at: string
          verification_attempt_id: string
          verification_work_item_id: string
          verifier_actor_id: string
        }
        Insert: {
          evidence_snapshot?: Json
          id?: string
          provenance_summary?: string | null
          result_kind: string
          result_payload: Json
          result_schema_version?: number
          submitted_at?: string
          verification_attempt_id: string
          verification_work_item_id: string
          verifier_actor_id: string
        }
        Update: {
          evidence_snapshot?: Json
          id?: string
          provenance_summary?: string | null
          result_kind?: string
          result_payload?: Json
          result_schema_version?: number
          submitted_at?: string
          verification_attempt_id?: string
          verification_work_item_id?: string
          verifier_actor_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "catalog_verifier_results_verification_attempt_id_fkey"
            columns: ["verification_attempt_id"]
            isOneToOne: true
            referencedRelation: "catalog_verification_attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_results_verification_work_item_id_fkey"
            columns: ["verification_work_item_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_work_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "catalog_verifier_results_verifier_actor_id_fkey"
            columns: ["verifier_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      community_comment_versions: {
        Row: {
          body: string | null
          change_kind: string
          changed_at: string
          changed_by_user_id: string
          comment_id: string
          id: string
          version_number: number
        }
        Insert: {
          body?: string | null
          change_kind: string
          changed_at?: string
          changed_by_user_id: string
          comment_id: string
          id?: string
          version_number: number
        }
        Update: {
          body?: string | null
          change_kind?: string
          changed_at?: string
          changed_by_user_id?: string
          comment_id?: string
          id?: string
          version_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "community_comment_versions_comment_id_fkey"
            columns: ["comment_id"]
            isOneToOne: false
            referencedRelation: "community_comments"
            referencedColumns: ["id"]
          },
        ]
      }
      community_comments: {
        Row: {
          author_user_id: string
          body: string | null
          comment_id: string
          created_at: string
          discussion_id: string
          edited_at: string | null
          id: string
          parent_comment_id: string | null
          status: string
          tombstoned_at: string | null
        }
        Insert: {
          author_user_id: string
          body?: string | null
          comment_id?: string
          created_at?: string
          discussion_id: string
          edited_at?: string | null
          id?: string
          parent_comment_id?: string | null
          status?: string
          tombstoned_at?: string | null
        }
        Update: {
          author_user_id?: string
          body?: string | null
          comment_id?: string
          created_at?: string
          discussion_id?: string
          edited_at?: string | null
          id?: string
          parent_comment_id?: string | null
          status?: string
          tombstoned_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "community_comments_author_user_id_fkey"
            columns: ["author_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "community_comments_discussion_id_fkey"
            columns: ["discussion_id"]
            isOneToOne: false
            referencedRelation: "community_discussions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_comments_parent_comment_id_discussion_id_fkey"
            columns: ["parent_comment_id", "discussion_id"]
            isOneToOne: false
            referencedRelation: "community_comments"
            referencedColumns: ["id", "discussion_id"]
          },
        ]
      }
      community_discussions: {
        Row: {
          comment_count: number
          competition_id: string | null
          context_kind: string
          created_at: string
          created_by_user_id: string
          discussion_id: string
          id: string
          news_item_id: string
          sport_id: string | null
          team_id: string | null
        }
        Insert: {
          comment_count?: number
          competition_id?: string | null
          context_kind: string
          created_at?: string
          created_by_user_id: string
          discussion_id?: string
          id?: string
          news_item_id: string
          sport_id?: string | null
          team_id?: string | null
        }
        Update: {
          comment_count?: number
          competition_id?: string | null
          context_kind?: string
          created_at?: string
          created_by_user_id?: string
          discussion_id?: string
          id?: string
          news_item_id?: string
          sport_id?: string | null
          team_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "community_discussions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_discussions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "community_discussions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_discussions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_discussions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_discussions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_discussions_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_discussions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_discussions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "community_discussions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      community_hide_intents: {
        Row: {
          created_at: string
          hidden_id: string
          hide_intent_id: string
          hider_id: string
        }
        Insert: {
          created_at?: string
          hidden_id: string
          hide_intent_id?: string
          hider_id: string
        }
        Update: {
          created_at?: string
          hidden_id?: string
          hide_intent_id?: string
          hider_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "community_hide_intents_hidden_id_fkey"
            columns: ["hidden_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "community_hide_intents_hider_id_fkey"
            columns: ["hider_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      community_moderation_actions: {
        Row: {
          action_id: string
          action_type: string
          comment_id: string
          created_at: string
          id: string
          reason: string
          report_id: string
          restriction_id: string | null
          staff_user_id: string
          target_user_id: string
        }
        Insert: {
          action_id?: string
          action_type: string
          comment_id: string
          created_at?: string
          id?: string
          reason: string
          report_id: string
          restriction_id?: string | null
          staff_user_id: string
          target_user_id: string
        }
        Update: {
          action_id?: string
          action_type?: string
          comment_id?: string
          created_at?: string
          id?: string
          reason?: string
          report_id?: string
          restriction_id?: string | null
          staff_user_id?: string
          target_user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "community_moderation_actions_comment_id_fkey"
            columns: ["comment_id"]
            isOneToOne: false
            referencedRelation: "community_comments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_moderation_actions_report_id_fkey"
            columns: ["report_id"]
            isOneToOne: false
            referencedRelation: "community_reports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_moderation_actions_restriction_id_fkey"
            columns: ["restriction_id"]
            isOneToOne: false
            referencedRelation: "community_posting_restrictions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_moderation_actions_target_user_id_fkey"
            columns: ["target_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      community_moderation_notices: {
        Row: {
          created_at: string
          id: string
          message: string
          moderation_action_id: string | null
          notice_id: string
          notice_type: string
          read_at: string | null
          restriction_lift_id: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          message: string
          moderation_action_id?: string | null
          notice_id?: string
          notice_type: string
          read_at?: string | null
          restriction_lift_id?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          message?: string
          moderation_action_id?: string | null
          notice_id?: string
          notice_type?: string
          read_at?: string | null
          restriction_lift_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "community_moderation_notices_moderation_action_id_fkey"
            columns: ["moderation_action_id"]
            isOneToOne: false
            referencedRelation: "community_moderation_actions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_moderation_notices_restriction_lift_id_fkey"
            columns: ["restriction_lift_id"]
            isOneToOne: true
            referencedRelation: "community_posting_restriction_lifts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_moderation_notices_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      community_notifications: {
        Row: {
          actor_user_id: string | null
          created_at: string
          id: string
          metadata: Json
          notification_id: string
          notification_type: string
          read_at: string | null
          reply_comment_id: string | null
          requester_relation_id: string | null
          user_id: string
        }
        Insert: {
          actor_user_id?: string | null
          created_at?: string
          id?: string
          metadata?: Json
          notification_id?: string
          notification_type: string
          read_at?: string | null
          reply_comment_id?: string | null
          requester_relation_id?: string | null
          user_id: string
        }
        Update: {
          actor_user_id?: string | null
          created_at?: string
          id?: string
          metadata?: Json
          notification_id?: string
          notification_type?: string
          read_at?: string | null
          reply_comment_id?: string | null
          requester_relation_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "community_notifications_actor_user_id_fkey"
            columns: ["actor_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
          {
            foreignKeyName: "community_notifications_reply_comment_id_fkey"
            columns: ["reply_comment_id"]
            isOneToOne: false
            referencedRelation: "community_comments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_notifications_requester_relation_fk"
            columns: ["requester_relation_id"]
            isOneToOne: false
            referencedRelation: "user_news_follow_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      community_posting_restriction_lifts: {
        Row: {
          id: string
          lift_id: string
          lifted_at: string
          lifted_by_staff_user_id: string
          reason: string
          restriction_id: string
        }
        Insert: {
          id?: string
          lift_id?: string
          lifted_at?: string
          lifted_by_staff_user_id: string
          reason: string
          restriction_id: string
        }
        Update: {
          id?: string
          lift_id?: string
          lifted_at?: string
          lifted_by_staff_user_id?: string
          reason?: string
          restriction_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "community_posting_restriction_lifts_restriction_id_fkey"
            columns: ["restriction_id"]
            isOneToOne: true
            referencedRelation: "community_posting_restrictions"
            referencedColumns: ["id"]
          },
        ]
      }
      community_posting_restrictions: {
        Row: {
          applied_by_staff_user_id: string
          created_at: string
          ends_at: string
          id: string
          ordinal: number
          originating_report_id: string | null
          reason: string
          restriction_id: string
          starts_at: string
          user_id: string
        }
        Insert: {
          applied_by_staff_user_id: string
          created_at?: string
          ends_at: string
          id?: string
          ordinal: number
          originating_report_id?: string | null
          reason: string
          restriction_id?: string
          starts_at: string
          user_id: string
        }
        Update: {
          applied_by_staff_user_id?: string
          created_at?: string
          ends_at?: string
          id?: string
          ordinal?: number
          originating_report_id?: string | null
          reason?: string
          restriction_id?: string
          starts_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "community_posting_restrictions_originating_report_id_fkey"
            columns: ["originating_report_id"]
            isOneToOne: false
            referencedRelation: "community_reports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_posting_restrictions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      community_reports: {
        Row: {
          comment_id: string
          created_at: string
          explanation: string | null
          id: string
          reason: string
          report_id: string
          reported_body: string
          reported_edited_at: string | null
          reported_version_number: number
          reporting_user_id: string
          resolved_at: string | null
          status: string
        }
        Insert: {
          comment_id: string
          created_at?: string
          explanation?: string | null
          id?: string
          reason: string
          report_id?: string
          reported_body: string
          reported_edited_at?: string | null
          reported_version_number: number
          reporting_user_id: string
          resolved_at?: string | null
          status?: string
        }
        Update: {
          comment_id?: string
          created_at?: string
          explanation?: string | null
          id?: string
          reason?: string
          report_id?: string
          reported_body?: string
          reported_edited_at?: string | null
          reported_version_number?: number
          reporting_user_id?: string
          resolved_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "community_reports_comment_id_fkey"
            columns: ["comment_id"]
            isOneToOne: false
            referencedRelation: "community_comments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "community_reports_reporting_user_id_fkey"
            columns: ["reporting_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      competition_alias_versions: {
        Row: {
          alias: string
          alias_type: string
          competition_id: string
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          locale: string | null
          normalized_alias: string | null
          record_status: string
          superseded_at: string | null
          verification_decision_id: string | null
        }
        Insert: {
          alias: string
          alias_type: string
          competition_id: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          locale?: string | null
          normalized_alias?: string | null
          record_status: string
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Update: {
          alias?: string
          alias_type?: string
          competition_id?: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          locale?: string | null
          normalized_alias?: string | null
          record_status?: string
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "competition_alias_versions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_alias_versions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "competition_alias_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_alias_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      competition_edition_relationship_versions: {
        Row: {
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          record_status: string
          relationship_type: string
          source_competition_edition_id: string
          superseded_at: string | null
          target_competition_edition_id: string
          verification_decision_id: string | null
        }
        Insert: {
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status: string
          relationship_type: string
          source_competition_edition_id: string
          superseded_at?: string | null
          target_competition_edition_id: string
          verification_decision_id?: string | null
        }
        Update: {
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status?: string
          relationship_type?: string
          source_competition_edition_id?: string
          superseded_at?: string | null
          target_competition_edition_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "competition_edition_relations_source_competition_edition_i_fkey"
            columns: ["source_competition_edition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_edition_relations_source_competition_edition_i_fkey"
            columns: ["source_competition_edition_id"]
            isOneToOne: false
            referencedRelation: "competition_edition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "competition_edition_relations_target_competition_edition_i_fkey"
            columns: ["target_competition_edition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_edition_relations_target_competition_edition_i_fkey"
            columns: ["target_competition_edition_id"]
            isOneToOne: false
            referencedRelation: "competition_edition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "competition_edition_relationship__verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_edition_relationship_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
        ]
      }
      competition_edition_versions: {
        Row: {
          active: boolean
          competition_edition_id: string
          created_at: string
          display_name: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          ends_on: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          record_status: string
          season_label: string | null
          starts_on: string | null
          superseded_at: string | null
          verification_decision_id: string | null
        }
        Insert: {
          active?: boolean
          competition_edition_id: string
          created_at?: string
          display_name: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          ends_on?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status: string
          season_label?: string | null
          starts_on?: string | null
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Update: {
          active?: boolean
          competition_edition_id?: string
          created_at?: string
          display_name?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          ends_on?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status?: string
          season_label?: string | null
          starts_on?: string | null
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "competition_edition_versions_competition_edition_id_fkey"
            columns: ["competition_edition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_edition_versions_competition_edition_id_fkey"
            columns: ["competition_edition_id"]
            isOneToOne: false
            referencedRelation: "competition_edition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "competition_edition_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_edition_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      competition_filter_group_membership_versions: {
        Row: {
          competition_id: string
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          filter_group_id: string
          id: string
          import_batch_id: string | null
          is_current: boolean
          record_status: string
          sort_order: number
          superseded_at: string | null
          verification_decision_id: string | null
        }
        Insert: {
          competition_id: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          filter_group_id: string
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status: string
          sort_order?: number
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Update: {
          competition_id?: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          filter_group_id?: string
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status?: string
          sort_order?: number
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "competition_filter_group_membersh_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_filter_group_membership_versio_filter_group_id_fkey"
            columns: ["filter_group_id"]
            isOneToOne: false
            referencedRelation: "catalog_competition_filter_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_filter_group_membership_versio_filter_group_id_fkey"
            columns: ["filter_group_id"]
            isOneToOne: false
            referencedRelation: "competition_filter_group_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "competition_filter_group_membership_versio_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_filter_group_membership_version_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_filter_group_membership_version_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      competition_filter_group_versions: {
        Row: {
          active: boolean
          created_at: string
          description: string | null
          display_name: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          filter_group_id: string
          id: string
          import_batch_id: string | null
          is_current: boolean
          record_status: string
          superseded_at: string | null
          verification_decision_id: string | null
        }
        Insert: {
          active?: boolean
          created_at?: string
          description?: string | null
          display_name: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          filter_group_id: string
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status: string
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Update: {
          active?: boolean
          created_at?: string
          description?: string | null
          display_name?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          filter_group_id?: string
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status?: string
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "competition_filter_group_versions_filter_group_id_fkey"
            columns: ["filter_group_id"]
            isOneToOne: false
            referencedRelation: "catalog_competition_filter_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_filter_group_versions_filter_group_id_fkey"
            columns: ["filter_group_id"]
            isOneToOne: false
            referencedRelation: "competition_filter_group_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "competition_filter_group_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_filter_group_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      competition_identity_versions: {
        Row: {
          active: boolean
          competition_id: string
          country_region: string | null
          created_at: string
          display_name: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          primary_languages: string[]
          record_status: string
          short_name: string | null
          superseded_at: string | null
          verification_decision_id: string | null
        }
        Insert: {
          active?: boolean
          competition_id: string
          country_region?: string | null
          created_at?: string
          display_name: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          primary_languages?: string[]
          record_status: string
          short_name?: string | null
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Update: {
          active?: boolean
          competition_id?: string
          country_region?: string | null
          created_at?: string
          display_name?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          primary_languages?: string[]
          record_status?: string
          short_name?: string | null
          superseded_at?: string | null
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "competition_identity_versions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_identity_versions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "competition_identity_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_identity_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      competition_kinds: {
        Row: {
          active: boolean
          created_at: string
          description: string | null
          display_name: string
          id: string
          kind_id: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          description?: string | null
          display_name: string
          id?: string
          kind_id: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          description?: string | null
          display_name?: string
          id?: string
          kind_id?: string
          updated_at?: string
        }
        Relationships: []
      }
      competition_relationship_versions: {
        Row: {
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          record_status: string
          relationship_type: string
          source_competition_id: string
          superseded_at: string | null
          target_competition_id: string
          verification_decision_id: string | null
        }
        Insert: {
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status: string
          relationship_type: string
          source_competition_id: string
          superseded_at?: string | null
          target_competition_id: string
          verification_decision_id?: string | null
        }
        Update: {
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status?: string
          relationship_type?: string
          source_competition_id?: string
          superseded_at?: string | null
          target_competition_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "competition_relationship_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_relationship_versions_source_competition_id_fkey"
            columns: ["source_competition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_relationship_versions_source_competition_id_fkey"
            columns: ["source_competition_id"]
            isOneToOne: false
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "competition_relationship_versions_target_competition_id_fkey"
            columns: ["target_competition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_relationship_versions_target_competition_id_fkey"
            columns: ["target_competition_id"]
            isOneToOne: false
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "competition_relationship_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      fan_identities: {
        Row: {
          additional_identity: Json
          fan_since: string | null
          favorite_players: string | null
          game_day_ritual: string | null
          superstition: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          additional_identity?: Json
          fan_since?: string | null
          favorite_players?: string | null
          game_day_ritual?: string | null
          superstition?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          additional_identity?: Json
          fan_since?: string | null
          favorite_players?: string | null
          game_day_ritual?: string | null
          superstition?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "fan_identities_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      information_lineage_resolution_attempts: {
        Row: {
          actor_id: string
          attempt_number: number
          claimed_at: string
          ended_at: string | null
          failure_category: string | null
          failure_reason: string | null
          id: string
          last_heartbeat_at: string
          lease_expires_at: string
          lease_token: string
          outcome: string | null
          work_item_id: string
        }
        Insert: {
          actor_id: string
          attempt_number: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at: string
          lease_token: string
          outcome?: string | null
          work_item_id: string
        }
        Update: {
          actor_id?: string
          attempt_number?: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at?: string
          lease_token?: string
          outcome?: string | null
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "information_lineage_resolution_attempts_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_resolution_attempts_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_resolution_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      information_lineage_resolution_policies: {
        Row: {
          active: boolean
          automatically_permitted_actions: string[]
          configuration: Json
          created_at: string
          created_by_actor_id: string | null
          data_type: string
          id: string
          is_current: boolean
          policy_key: string
          superseded_at: string | null
          version: number
        }
        Insert: {
          active?: boolean
          automatically_permitted_actions?: string[]
          configuration?: Json
          created_at?: string
          created_by_actor_id?: string | null
          data_type: string
          id?: string
          is_current?: boolean
          policy_key: string
          superseded_at?: string | null
          version: number
        }
        Update: {
          active?: boolean
          automatically_permitted_actions?: string[]
          configuration?: Json
          created_at?: string
          created_by_actor_id?: string | null
          data_type?: string
          id?: string
          is_current?: boolean
          policy_key?: string
          superseded_at?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "information_lineage_resolution_policie_created_by_actor_id_fkey"
            columns: ["created_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      information_lineage_resolution_results: {
        Row: {
          disposition: string
          id: string
          policy_id: string | null
          proposed_lineage_key: string | null
          provenance: Json
          resolution_action: string
          resolution_basis: string
          result_schema_version: number
          submitted_at: string
          submitted_by_actor_id: string
          work_item_id: string
        }
        Insert: {
          disposition: string
          id?: string
          policy_id?: string | null
          proposed_lineage_key?: string | null
          provenance?: Json
          resolution_action: string
          resolution_basis: string
          result_schema_version?: number
          submitted_at?: string
          submitted_by_actor_id: string
          work_item_id: string
        }
        Update: {
          disposition?: string
          id?: string
          policy_id?: string | null
          proposed_lineage_key?: string | null
          provenance?: Json
          resolution_action?: string
          resolution_basis?: string
          result_schema_version?: number
          submitted_at?: string
          submitted_by_actor_id?: string
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "information_lineage_resolution_resul_submitted_by_actor_id_fkey"
            columns: ["submitted_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_resolution_results_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_resolution_policies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_resolution_results_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: true
            referencedRelation: "information_lineage_resolution_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      information_lineage_resolution_work_items: {
        Row: {
          attempt_count: number
          available_at: string
          claimed_by_actor_id: string | null
          completed_at: string | null
          created_at: string
          data_type: string
          evidence_id: string
          evidence_kind: string
          failure_category: string | null
          failure_reason: string | null
          id: string
          lease_expires_at: string | null
          lease_token: string | null
          status: string
          subject_id: string
          subject_type: string
          updated_at: string
        }
        Insert: {
          attempt_count?: number
          available_at?: string
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          data_type: string
          evidence_id: string
          evidence_kind: string
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          lease_expires_at?: string | null
          lease_token?: string | null
          status?: string
          subject_id: string
          subject_type: string
          updated_at?: string
        }
        Update: {
          attempt_count?: number
          available_at?: string
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          data_type?: string
          evidence_id?: string
          evidence_kind?: string
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          lease_expires_at?: string | null
          lease_token?: string | null
          status?: string
          subject_id?: string
          subject_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "information_lineage_resolution_work_it_claimed_by_actor_id_fkey"
            columns: ["claimed_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      information_lineage_review_attempts: {
        Row: {
          actor_id: string
          attempt_number: number
          claimed_at: string
          ended_at: string | null
          failure_category: string | null
          failure_reason: string | null
          id: string
          last_heartbeat_at: string
          lease_expires_at: string
          lease_token: string
          outcome: string | null
          work_item_id: string
        }
        Insert: {
          actor_id: string
          attempt_number: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at: string
          lease_token: string
          outcome?: string | null
          work_item_id: string
        }
        Update: {
          actor_id?: string
          attempt_number?: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at?: string
          lease_token?: string
          outcome?: string | null
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "information_lineage_review_attempts_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_review_attempts_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_review_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      information_lineage_review_decisions: {
        Row: {
          applied_lineage_key: string | null
          applied_lineage_version_id: string | null
          attempt_id: string
          decided_at: string
          disposition: string
          id: string
          new_lineage_display_name: string | null
          new_lineage_origin_url: string | null
          provenance: Json
          review_basis: string
          reviewed_by_actor_id: string
          terminal_exception_code: string | null
          terminal_exception_reason: string | null
          work_item_id: string
        }
        Insert: {
          applied_lineage_key?: string | null
          applied_lineage_version_id?: string | null
          attempt_id: string
          decided_at?: string
          disposition: string
          id?: string
          new_lineage_display_name?: string | null
          new_lineage_origin_url?: string | null
          provenance?: Json
          review_basis: string
          reviewed_by_actor_id: string
          terminal_exception_code?: string | null
          terminal_exception_reason?: string | null
          work_item_id: string
        }
        Update: {
          applied_lineage_key?: string | null
          applied_lineage_version_id?: string | null
          attempt_id?: string
          decided_at?: string
          disposition?: string
          id?: string
          new_lineage_display_name?: string | null
          new_lineage_origin_url?: string | null
          provenance?: Json
          review_basis?: string
          reviewed_by_actor_id?: string
          terminal_exception_code?: string | null
          terminal_exception_reason?: string | null
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "information_lineage_review_deci_applied_lineage_version_id_fkey"
            columns: ["applied_lineage_version_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_review_decisions_attempt_id_fkey"
            columns: ["attempt_id"]
            isOneToOne: true
            referencedRelation: "information_lineage_review_attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_review_decisions_reviewed_by_actor_id_fkey"
            columns: ["reviewed_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_review_decisions_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: true
            referencedRelation: "information_lineage_review_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      information_lineage_review_work_events: {
        Row: {
          actor_id: string | null
          attempt_number: number | null
          details: Json
          event_type: string
          id: number
          occurred_at: string
          work_item_id: string
        }
        Insert: {
          actor_id?: string | null
          attempt_number?: number | null
          details?: Json
          event_type: string
          id?: never
          occurred_at?: string
          work_item_id: string
        }
        Update: {
          actor_id?: string | null
          attempt_number?: number | null
          details?: Json
          event_type?: string
          id?: never
          occurred_at?: string
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "information_lineage_review_work_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_review_work_events_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_review_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      information_lineage_review_work_items: {
        Row: {
          attempt_count: number
          available_at: string
          claimed_by_actor_id: string | null
          completed_at: string | null
          created_at: string
          data_type: string
          failure_category: string | null
          failure_reason: string | null
          id: string
          lease_expires_at: string | null
          lease_token: string | null
          resolution_result_id: string
          status: string
          updated_at: string
        }
        Insert: {
          attempt_count?: number
          available_at?: string
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          data_type: string
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          lease_expires_at?: string | null
          lease_token?: string | null
          resolution_result_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          attempt_count?: number
          available_at?: string
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          data_type?: string
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          lease_expires_at?: string | null
          lease_token?: string | null
          resolution_result_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "information_lineage_review_work_items_claimed_by_actor_id_fkey"
            columns: ["claimed_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_review_work_items_resolution_result_id_fkey"
            columns: ["resolution_result_id"]
            isOneToOne: true
            referencedRelation: "information_lineage_resolution_results"
            referencedColumns: ["id"]
          },
        ]
      }
      information_lineage_versions: {
        Row: {
          canonical_lineage_id: string | null
          created_at: string
          display_name: string
          id: string
          is_current: boolean
          lineage_id: string
          notes: string | null
          origin_url: string | null
          provenance: Json
          review_status: string
          reviewed_by_actor_id: string | null
          superseded_at: string | null
          version: number
        }
        Insert: {
          canonical_lineage_id?: string | null
          created_at?: string
          display_name: string
          id?: string
          is_current?: boolean
          lineage_id: string
          notes?: string | null
          origin_url?: string | null
          provenance?: Json
          review_status: string
          reviewed_by_actor_id?: string | null
          superseded_at?: string | null
          version: number
        }
        Update: {
          canonical_lineage_id?: string | null
          created_at?: string
          display_name?: string
          id?: string
          is_current?: boolean
          lineage_id?: string
          notes?: string | null
          origin_url?: string | null
          provenance?: Json
          review_status?: string
          reviewed_by_actor_id?: string | null
          superseded_at?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "information_lineage_versions_canonical_lineage_id_fkey"
            columns: ["canonical_lineage_id"]
            isOneToOne: false
            referencedRelation: "information_lineages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_versions_lineage_id_fkey"
            columns: ["lineage_id"]
            isOneToOne: false
            referencedRelation: "information_lineages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "information_lineage_versions_reviewed_by_actor_id_fkey"
            columns: ["reviewed_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      information_lineages: {
        Row: {
          created_at: string
          data_type: string
          id: string
          lineage_key: string
        }
        Insert: {
          created_at?: string
          data_type: string
          id?: string
          lineage_key: string
        }
        Update: {
          created_at?: string
          data_type?: string
          id?: string
          lineage_key?: string
        }
        Relationships: []
      }
      news_author_profiles: {
        Row: {
          author_id: string
          created_at: string
          created_by_resolution_decision_id: string | null
          id: string
          person_id: string
        }
        Insert: {
          author_id?: string
          created_at?: string
          created_by_resolution_decision_id?: string | null
          id?: string
          person_id: string
        }
        Update: {
          author_id?: string
          created_at?: string
          created_by_resolution_decision_id?: string | null
          id?: string
          person_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_author_created_decision_fk"
            columns: ["created_by_resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_author_profiles_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: true
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
        ]
      }
      news_byline_mentions: {
        Row: {
          created_at: string
          created_by_decision_id: string
          id: string
          manifestation_id: string
          ordinal: number
          primary_evidence_id: string
          raw_attribution: string
          visible_profile_url: string | null
        }
        Insert: {
          created_at?: string
          created_by_decision_id: string
          id?: string
          manifestation_id: string
          ordinal: number
          primary_evidence_id: string
          raw_attribution: string
          visible_profile_url?: string | null
        }
        Update: {
          created_at?: string
          created_by_decision_id?: string
          id?: string
          manifestation_id?: string
          ordinal?: number
          primary_evidence_id?: string
          raw_attribution?: string
          visible_profile_url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_byline_mentions_created_by_decision_id_fkey"
            columns: ["created_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_mentions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_byline_mentions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_manifestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_mentions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_byline_mentions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_byline_mentions_primary_evidence_id_fkey"
            columns: ["primary_evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
        ]
      }
      news_byline_resolution_versions: {
        Row: {
          byline_mention_id: string
          closed_by_decision_id: string | null
          contributor_profile_id: string | null
          created_at: string
          decision_id: string
          id: string
          identity_resolution_decision_id: string | null
          is_current: boolean
          organizational_contributor_id: string | null
          person_id: string | null
          recorded_from: string
          recorded_to: string | null
          resolution_basis: string
          show_id: string | null
          superseded_at: string | null
          supersedes_resolution_id: string | null
          target_identity_type: string
        }
        Insert: {
          byline_mention_id: string
          closed_by_decision_id?: string | null
          contributor_profile_id?: string | null
          created_at?: string
          decision_id: string
          id?: string
          identity_resolution_decision_id?: string | null
          is_current?: boolean
          organizational_contributor_id?: string | null
          person_id?: string | null
          recorded_from: string
          recorded_to?: string | null
          resolution_basis: string
          show_id?: string | null
          superseded_at?: string | null
          supersedes_resolution_id?: string | null
          target_identity_type: string
        }
        Update: {
          byline_mention_id?: string
          closed_by_decision_id?: string | null
          contributor_profile_id?: string | null
          created_at?: string
          decision_id?: string
          id?: string
          identity_resolution_decision_id?: string | null
          is_current?: boolean
          organizational_contributor_id?: string | null
          person_id?: string | null
          recorded_from?: string
          recorded_to?: string | null
          resolution_basis?: string
          show_id?: string | null
          superseded_at?: string | null
          supersedes_resolution_id?: string | null
          target_identity_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_byline_resolution_versio_identity_resolution_decision_fkey"
            columns: ["identity_resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_resolution_versio_organizational_contributor_i_fkey"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_resolution_versions_byline_mention_id_fkey"
            columns: ["byline_mention_id"]
            isOneToOne: false
            referencedRelation: "news_byline_mentions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_resolution_versions_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_resolution_versions_contributor_profile_id_fkey"
            columns: ["contributor_profile_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_contributor_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_resolution_versions_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_resolution_versions_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_resolution_versions_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_byline_resolution_versions_supersedes_resolution_id_fkey"
            columns: ["supersedes_resolution_id"]
            isOneToOne: false
            referencedRelation: "news_byline_resolution_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_content_decision_evidence: {
        Row: {
          created_at: string
          decision_id: string
          evidence_id: string
        }
        Insert: {
          created_at?: string
          decision_id: string
          evidence_id: string
        }
        Update: {
          created_at?: string
          decision_id?: string
          evidence_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_content_decision_evidence_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_decision_evidence_evidence_id_fkey"
            columns: ["evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
        ]
      }
      news_content_decisions: {
        Row: {
          action: string
          decided_at: string
          decided_by_actor_id: string | null
          decided_by_user_id: string | null
          decision_id: string
          decision_origin: string
          id: string
          notes: string | null
          source_publisher_id: string | null
        }
        Insert: {
          action: string
          decided_at?: string
          decided_by_actor_id?: string | null
          decided_by_user_id?: string | null
          decision_id?: string
          decision_origin: string
          id?: string
          notes?: string | null
          source_publisher_id?: string | null
        }
        Update: {
          action?: string
          decided_at?: string
          decided_by_actor_id?: string | null
          decided_by_user_id?: string | null
          decision_id?: string
          decision_origin?: string
          id?: string
          notes?: string | null
          source_publisher_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_content_decisions_decided_by_actor_id_fkey"
            columns: ["decided_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_decisions_source_publisher_id_fkey"
            columns: ["source_publisher_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_content_decisions_source_publisher_id_fkey"
            columns: ["source_publisher_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_content_decisions_source_publisher_id_fkey"
            columns: ["source_publisher_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_content_decisions_source_publisher_id_fkey"
            columns: ["source_publisher_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_content_decisions_source_publisher_id_fkey"
            columns: ["source_publisher_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      news_content_evidence: {
        Row: {
          created_at: string
          evidence_id: string
          evidence_kind: string
          evidence_summary: string
          evidence_url: string
          id: string
          observed_at: string
          publisher_source_id: string
          recorded_by_decision_id: string
          source_url_scope_version_id: string
        }
        Insert: {
          created_at?: string
          evidence_id?: string
          evidence_kind: string
          evidence_summary: string
          evidence_url: string
          id?: string
          observed_at: string
          publisher_source_id: string
          recorded_by_decision_id: string
          source_url_scope_version_id: string
        }
        Update: {
          created_at?: string
          evidence_id?: string
          evidence_kind?: string
          evidence_summary?: string
          evidence_url?: string
          id?: string
          observed_at?: string
          publisher_source_id?: string
          recorded_by_decision_id?: string
          source_url_scope_version_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_content_evidence_evidence_kind_fkey"
            columns: ["evidence_kind"]
            isOneToOne: false
            referencedRelation: "news_content_evidence_kinds"
            referencedColumns: ["evidence_kind"]
          },
          {
            foreignKeyName: "news_content_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_content_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_content_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_content_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_content_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_evidence_recorded_by_decision_id_fkey"
            columns: ["recorded_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_evidence_source_url_scope_version_id_fkey"
            columns: ["source_url_scope_version_id"]
            isOneToOne: false
            referencedRelation: "trusted_source_url_scope_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_content_evidence_kinds: {
        Row: {
          active: boolean
          created_at: string
          description: string
          display_name: string
          evidence_kind: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          description: string
          display_name: string
          evidence_kind: string
        }
        Update: {
          active?: boolean
          created_at?: string
          description?: string
          display_name?: string
          evidence_kind?: string
        }
        Relationships: []
      }
      news_content_review_case_types: {
        Row: {
          active: boolean
          case_type: string
          description: string
          display_name: string
        }
        Insert: {
          active?: boolean
          case_type: string
          description: string
          display_name: string
        }
        Update: {
          active?: boolean
          case_type?: string
          description?: string
          display_name?: string
        }
        Relationships: []
      }
      news_content_review_cases: {
        Row: {
          case_type: string
          context: Json
          created_at: string
          id: string
          manifestation_id: string | null
          news_item_id: string | null
          opened_by_decision_id: string
          resolved_at: string | null
          review_case_id: string
          status: string
          subject_byline_mention_id: string | null
          subject_identity_type: string | null
          subject_organizational_contributor_id: string | null
          subject_person_id: string | null
          subject_show_id: string | null
          unresolved_question: string
          updated_at: string
        }
        Insert: {
          case_type: string
          context?: Json
          created_at?: string
          id?: string
          manifestation_id?: string | null
          news_item_id?: string | null
          opened_by_decision_id: string
          resolved_at?: string | null
          review_case_id?: string
          status?: string
          subject_byline_mention_id?: string | null
          subject_identity_type?: string | null
          subject_organizational_contributor_id?: string | null
          subject_person_id?: string | null
          subject_show_id?: string | null
          unresolved_question: string
          updated_at?: string
        }
        Update: {
          case_type?: string
          context?: Json
          created_at?: string
          id?: string
          manifestation_id?: string | null
          news_item_id?: string | null
          opened_by_decision_id?: string
          resolved_at?: string | null
          review_case_id?: string
          status?: string
          subject_byline_mention_id?: string | null
          subject_identity_type?: string | null
          subject_organizational_contributor_id?: string | null
          subject_person_id?: string | null
          subject_show_id?: string | null
          unresolved_question?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_content_review_cases_case_type_fkey"
            columns: ["case_type"]
            isOneToOne: false
            referencedRelation: "news_content_review_case_types"
            referencedColumns: ["case_type"]
          },
          {
            foreignKeyName: "news_content_review_cases_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_content_review_cases_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_manifestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_content_review_cases_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_content_review_cases_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_opened_by_decision_id_fkey"
            columns: ["opened_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_subject_byline_mention_id_fkey"
            columns: ["subject_byline_mention_id"]
            isOneToOne: false
            referencedRelation: "news_byline_mentions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_subject_organizational_contribut_fkey"
            columns: ["subject_organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_subject_person_id_fkey"
            columns: ["subject_person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_subject_show_id_fkey"
            columns: ["subject_show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_content_review_decisions: {
        Row: {
          action: string
          action_payload_snapshot: Json
          content_decision_id: string
          decided_at: string
          decided_by_user_id: string
          id: string
          notes: string | null
          question_snapshot: string
          review_case_id: string
          supersedes_review_decision_id: string | null
        }
        Insert: {
          action: string
          action_payload_snapshot?: Json
          content_decision_id: string
          decided_at?: string
          decided_by_user_id: string
          id?: string
          notes?: string | null
          question_snapshot: string
          review_case_id: string
          supersedes_review_decision_id?: string | null
        }
        Update: {
          action?: string
          action_payload_snapshot?: Json
          content_decision_id?: string
          decided_at?: string
          decided_by_user_id?: string
          id?: string
          notes?: string | null
          question_snapshot?: string
          review_case_id?: string
          supersedes_review_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_content_review_decisions_content_decision_id_fkey"
            columns: ["content_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_decisions_review_case_id_fkey"
            columns: ["review_case_id"]
            isOneToOne: false
            referencedRelation: "news_content_review_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_decisions_review_case_id_fkey"
            columns: ["review_case_id"]
            isOneToOne: false
            referencedRelation: "news_content_review_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_decisions_supersedes_review_decision_i_fkey"
            columns: ["supersedes_review_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_review_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_deduplication_cases: {
        Row: {
          created_at: string
          created_by_decision_id: string
          deduplication_case_id: string
          id: string
          manifestation_a_id: string
          manifestation_b_id: string
        }
        Insert: {
          created_at?: string
          created_by_decision_id: string
          deduplication_case_id?: string
          id?: string
          manifestation_a_id: string
          manifestation_b_id: string
        }
        Update: {
          created_at?: string
          created_by_decision_id?: string
          deduplication_case_id?: string
          id?: string
          manifestation_a_id?: string
          manifestation_b_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_deduplication_cases_created_by_decision_id_fkey"
            columns: ["created_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_deduplication_cases_manifestation_a_id_fkey"
            columns: ["manifestation_a_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_deduplication_cases_manifestation_a_id_fkey"
            columns: ["manifestation_a_id"]
            isOneToOne: false
            referencedRelation: "news_manifestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_deduplication_cases_manifestation_a_id_fkey"
            columns: ["manifestation_a_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_deduplication_cases_manifestation_a_id_fkey"
            columns: ["manifestation_a_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_deduplication_cases_manifestation_b_id_fkey"
            columns: ["manifestation_b_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_deduplication_cases_manifestation_b_id_fkey"
            columns: ["manifestation_b_id"]
            isOneToOne: false
            referencedRelation: "news_manifestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_deduplication_cases_manifestation_b_id_fkey"
            columns: ["manifestation_b_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_deduplication_cases_manifestation_b_id_fkey"
            columns: ["manifestation_b_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
        ]
      }
      news_deduplication_decision_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          decision_id: string
          deduplication_case_id: string
          id: string
          is_current: boolean
          outcome: string
          primary_evidence_id: string
          rationale: string
          recorded_from: string
          recorded_to: string | null
          superseded_at: string | null
          supersedes_deduplication_version_id: string | null
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id: string
          deduplication_case_id: string
          id?: string
          is_current?: boolean
          outcome: string
          primary_evidence_id: string
          rationale: string
          recorded_from: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_deduplication_version_id?: string | null
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id?: string
          deduplication_case_id?: string
          id?: string
          is_current?: boolean
          outcome?: string
          primary_evidence_id?: string
          rationale?: string
          recorded_from?: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_deduplication_version_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_deduplication_decision_v_supersedes_deduplication_ver_fkey"
            columns: ["supersedes_deduplication_version_id"]
            isOneToOne: false
            referencedRelation: "news_deduplication_decision_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_deduplication_decision_versions_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_deduplication_decision_versions_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_deduplication_decision_versions_deduplication_case_id_fkey"
            columns: ["deduplication_case_id"]
            isOneToOne: false
            referencedRelation: "news_deduplication_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_deduplication_decision_versions_primary_evidence_id_fkey"
            columns: ["primary_evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
        ]
      }
      news_demo_configuration_identities: {
        Row: {
          configuration_version_id: string
          created_at: string
          ordinal: number
          organizational_contributor_id: string | null
          person_id: string | null
          show_id: string | null
          target_type: string
        }
        Insert: {
          configuration_version_id: string
          created_at?: string
          ordinal: number
          organizational_contributor_id?: string | null
          person_id?: string | null
          show_id?: string | null
          target_type: string
        }
        Update: {
          configuration_version_id?: string
          created_at?: string
          ordinal?: number
          organizational_contributor_id?: string | null
          person_id?: string | null
          show_id?: string | null
          target_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_demo_configuration_ident_organizational_contributor_i_fkey"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_demo_configuration_identitie_configuration_version_id_fkey"
            columns: ["configuration_version_id"]
            isOneToOne: false
            referencedRelation: "news_demo_configuration_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_demo_configuration_identities_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_demo_configuration_identities_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_demo_configuration_versions: {
        Row: {
          closed_by_decision_id: string | null
          configuration_key: string
          created_at: string
          decision_id: string
          id: string
          is_current: boolean
          recorded_from: string
          recorded_to: string | null
          superseded_at: string | null
          supersedes_version_id: string | null
          version_number: number
        }
        Insert: {
          closed_by_decision_id?: string | null
          configuration_key?: string
          created_at?: string
          decision_id: string
          id?: string
          is_current?: boolean
          recorded_from: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_version_id?: string | null
          version_number: number
        }
        Update: {
          closed_by_decision_id?: string | null
          configuration_key?: string
          created_at?: string
          decision_id?: string
          id?: string
          is_current?: boolean
          recorded_from?: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_version_id?: string | null
          version_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "news_demo_configuration_versions_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_phase4_configuration_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_demo_configuration_versions_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_phase4_configuration_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_demo_configuration_versions_supersedes_version_id_fkey"
            columns: ["supersedes_version_id"]
            isOneToOne: false
            referencedRelation: "news_demo_configuration_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_follow_request_resolution_decisions: {
        Row: {
          decided_at: string
          decided_by_user_id: string
          id: string
          outcome: string
          reason: string
          request_target_id: string
          resolved_organizational_contributor_id: string | null
          resolved_person_id: string | null
          resolved_show_id: string | null
          resolved_target_type: string | null
        }
        Insert: {
          decided_at?: string
          decided_by_user_id: string
          id?: string
          outcome: string
          reason: string
          request_target_id: string
          resolved_organizational_contributor_id?: string | null
          resolved_person_id?: string | null
          resolved_show_id?: string | null
          resolved_target_type?: string | null
        }
        Update: {
          decided_at?: string
          decided_by_user_id?: string
          id?: string
          outcome?: string
          reason?: string
          request_target_id?: string
          resolved_organizational_contributor_id?: string | null
          resolved_person_id?: string | null
          resolved_show_id?: string | null
          resolved_target_type?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_follow_request_resolutio_resolved_organizational_cont_fkey"
            columns: ["resolved_organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_follow_request_resolution_decision_resolved_person_id_fkey"
            columns: ["resolved_person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_follow_request_resolution_decisions_request_target_id_fkey"
            columns: ["request_target_id"]
            isOneToOne: true
            referencedRelation: "news_follow_request_targets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_follow_request_resolution_decisions_resolved_show_id_fkey"
            columns: ["resolved_show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_follow_request_targets: {
        Row: {
          created_at: string
          display_input: string
          id: string
          input_kind: string
          normalized_input: string
          request_target_id: string
          resolution_state: string
          resolved_at: string | null
          resolved_by_user_id: string | null
          resolved_organizational_contributor_id: string | null
          resolved_person_id: string | null
          resolved_show_id: string | null
          resolved_target_type: string | null
          staff_reason: string | null
        }
        Insert: {
          created_at?: string
          display_input: string
          id?: string
          input_kind: string
          normalized_input: string
          request_target_id?: string
          resolution_state?: string
          resolved_at?: string | null
          resolved_by_user_id?: string | null
          resolved_organizational_contributor_id?: string | null
          resolved_person_id?: string | null
          resolved_show_id?: string | null
          resolved_target_type?: string | null
          staff_reason?: string | null
        }
        Update: {
          created_at?: string
          display_input?: string
          id?: string
          input_kind?: string
          normalized_input?: string
          request_target_id?: string
          resolution_state?: string
          resolved_at?: string | null
          resolved_by_user_id?: string | null
          resolved_organizational_contributor_id?: string | null
          resolved_person_id?: string | null
          resolved_show_id?: string | null
          resolved_target_type?: string | null
          staff_reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_follow_request_targets_resolved_organizational_contri_fkey"
            columns: ["resolved_organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_follow_request_targets_resolved_person_id_fkey"
            columns: ["resolved_person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_follow_request_targets_resolved_show_id_fkey"
            columns: ["resolved_show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_followable_identity_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          decision_id: string
          followable: boolean
          id: string
          is_current: boolean
          organizational_contributor_id: string | null
          person_id: string | null
          rationale: string
          recorded_from: string
          recorded_to: string | null
          show_id: string | null
          superseded_at: string | null
          supersedes_version_id: string | null
          target_type: string
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id: string
          followable: boolean
          id?: string
          is_current?: boolean
          organizational_contributor_id?: string | null
          person_id?: string | null
          rationale: string
          recorded_from: string
          recorded_to?: string | null
          show_id?: string | null
          superseded_at?: string | null
          supersedes_version_id?: string | null
          target_type: string
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id?: string
          followable?: boolean
          id?: string
          is_current?: boolean
          organizational_contributor_id?: string | null
          person_id?: string | null
          rationale?: string
          recorded_from?: string
          recorded_to?: string | null
          show_id?: string | null
          superseded_at?: string | null
          supersedes_version_id?: string | null
          target_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_followable_identity_vers_organizational_contributor_i_fkey"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_followable_identity_versions_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_phase4_configuration_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_followable_identity_versions_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_phase4_configuration_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_followable_identity_versions_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_followable_identity_versions_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_followable_identity_versions_supersedes_version_id_fkey"
            columns: ["supersedes_version_id"]
            isOneToOne: false
            referencedRelation: "news_followable_identity_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_identity_decision_evidence: {
        Row: {
          decision_id: string
          evidence_id: string
          evidence_role: string
        }
        Insert: {
          decision_id: string
          evidence_id: string
          evidence_role: string
        }
        Update: {
          decision_id?: string
          evidence_id?: string
          evidence_role?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_identity_decision_evidence_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_decision_evidence_evidence_id_fkey"
            columns: ["evidence_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_evidence"
            referencedColumns: ["id"]
          },
        ]
      }
      news_identity_evidence_kinds: {
        Row: {
          active: boolean
          can_bridge_person_identities: boolean
          created_at: string
          description: string
          display_name: string
          evidence_class: string
          evidence_kind: string
          subject_types: string[]
        }
        Insert: {
          active?: boolean
          can_bridge_person_identities?: boolean
          created_at?: string
          description: string
          display_name: string
          evidence_class: string
          evidence_kind: string
          subject_types: string[]
        }
        Update: {
          active?: boolean
          can_bridge_person_identities?: boolean
          created_at?: string
          description?: string
          display_name?: string
          evidence_class?: string
          evidence_kind?: string
          subject_types?: string[]
        }
        Relationships: []
      }
      news_identity_resolution_candidates: {
        Row: {
          candidate_kind: string
          case_id: string
          contributor_profile_id: string | null
          created_at: string
          display_name: string
          id: string
          identity_type: string
          normalized_name: string | null
          organizational_contributor_id: string | null
          person_id: string | null
          proposed_facts: Json
          recorded_by_decision_id: string | null
          show_id: string | null
        }
        Insert: {
          candidate_kind: string
          case_id: string
          contributor_profile_id?: string | null
          created_at?: string
          display_name: string
          id?: string
          identity_type: string
          normalized_name?: string | null
          organizational_contributor_id?: string | null
          person_id?: string | null
          proposed_facts?: Json
          recorded_by_decision_id?: string | null
          show_id?: string | null
        }
        Update: {
          candidate_kind?: string
          case_id?: string
          contributor_profile_id?: string | null
          created_at?: string
          display_name?: string
          id?: string
          identity_type?: string
          normalized_name?: string | null
          organizational_contributor_id?: string | null
          person_id?: string | null
          proposed_facts?: Json
          recorded_by_decision_id?: string | null
          show_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_identity_resolution_cand_organizational_contributor_i_fkey"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_candidate_recorded_by_decision_id_fkey"
            columns: ["recorded_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_candidates_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_candidates_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "news_identity_review_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_candidates_contributor_profile_id_fkey"
            columns: ["contributor_profile_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_contributor_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_candidates_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_candidates_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_identity_resolution_cases: {
        Row: {
          automatic_resolution_result: string | null
          case_id: string
          case_kind: string
          context: Json
          created_at: string
          created_by_user_id: string | null
          id: string
          normalized_proposed_name: string | null
          opened_by_decision_id: string | null
          profile_url: string | null
          proposed_identity_type: string | null
          proposed_name: string | null
          publisher_source_id: string | null
          raw_byline: string | null
          resolution_stop_reason: string | null
          resolved_at: string | null
          status: string
          subject_contributor_profile_id: string | null
          subject_organizational_contributor_id: string | null
          subject_person_id: string | null
          subject_show_id: string | null
          unresolved_question: string
          updated_at: string
        }
        Insert: {
          automatic_resolution_result?: string | null
          case_id?: string
          case_kind: string
          context?: Json
          created_at?: string
          created_by_user_id?: string | null
          id?: string
          normalized_proposed_name?: string | null
          opened_by_decision_id?: string | null
          profile_url?: string | null
          proposed_identity_type?: string | null
          proposed_name?: string | null
          publisher_source_id?: string | null
          raw_byline?: string | null
          resolution_stop_reason?: string | null
          resolved_at?: string | null
          status?: string
          subject_contributor_profile_id?: string | null
          subject_organizational_contributor_id?: string | null
          subject_person_id?: string | null
          subject_show_id?: string | null
          unresolved_question: string
          updated_at?: string
        }
        Update: {
          automatic_resolution_result?: string | null
          case_id?: string
          case_kind?: string
          context?: Json
          created_at?: string
          created_by_user_id?: string | null
          id?: string
          normalized_proposed_name?: string | null
          opened_by_decision_id?: string | null
          profile_url?: string | null
          proposed_identity_type?: string | null
          proposed_name?: string | null
          publisher_source_id?: string | null
          raw_byline?: string | null
          resolution_stop_reason?: string | null
          resolved_at?: string | null
          status?: string
          subject_contributor_profile_id?: string | null
          subject_organizational_contributor_id?: string | null
          subject_person_id?: string | null
          subject_show_id?: string | null
          unresolved_question?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_identity_resolution_case_subject_contributor_profile__fkey"
            columns: ["subject_contributor_profile_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_contributor_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_case_subject_organizational_contr_fkey"
            columns: ["subject_organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_opened_by_decision_id_fkey"
            columns: ["opened_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_subject_person_id_fkey"
            columns: ["subject_person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_subject_show_id_fkey"
            columns: ["subject_show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_identity_resolution_decisions: {
        Row: {
          action: string
          action_payload_snapshot: Json
          automatic_rule_key: string | null
          case_id: string
          decided_at: string
          decided_by_actor_id: string | null
          decided_by_user_id: string | null
          decision_origin: string
          id: string
          notes: string | null
          question_snapshot: string
          result_contributor_profile_id: string | null
          result_identity_type: string | null
          result_organizational_contributor_id: string | null
          result_person_id: string | null
          result_show_id: string | null
          selected_candidate_id: string | null
          stop_reason: string | null
          supersedes_decision_id: string | null
        }
        Insert: {
          action: string
          action_payload_snapshot?: Json
          automatic_rule_key?: string | null
          case_id: string
          decided_at?: string
          decided_by_actor_id?: string | null
          decided_by_user_id?: string | null
          decision_origin: string
          id?: string
          notes?: string | null
          question_snapshot: string
          result_contributor_profile_id?: string | null
          result_identity_type?: string | null
          result_organizational_contributor_id?: string | null
          result_person_id?: string | null
          result_show_id?: string | null
          selected_candidate_id?: string | null
          stop_reason?: string | null
          supersedes_decision_id?: string | null
        }
        Update: {
          action?: string
          action_payload_snapshot?: Json
          automatic_rule_key?: string | null
          case_id?: string
          decided_at?: string
          decided_by_actor_id?: string | null
          decided_by_user_id?: string | null
          decision_origin?: string
          id?: string
          notes?: string | null
          question_snapshot?: string
          result_contributor_profile_id?: string | null
          result_identity_type?: string | null
          result_organizational_contributor_id?: string | null
          result_person_id?: string | null
          result_show_id?: string | null
          selected_candidate_id?: string | null
          stop_reason?: string | null
          supersedes_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_identity_resolution_deci_result_contributor_profile_i_fkey"
            columns: ["result_contributor_profile_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_contributor_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_deci_result_organizational_contri_fkey"
            columns: ["result_organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_decisions_automatic_rule_key_fkey"
            columns: ["automatic_rule_key"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_rules"
            referencedColumns: ["rule_key"]
          },
          {
            foreignKeyName: "news_identity_resolution_decisions_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_decisions_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "news_identity_review_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_decisions_decided_by_actor_id_fkey"
            columns: ["decided_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_decisions_result_person_id_fkey"
            columns: ["result_person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_decisions_result_show_id_fkey"
            columns: ["result_show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_decisions_selected_candidate_id_fkey"
            columns: ["selected_candidate_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_decisions_supersedes_decision_id_fkey"
            columns: ["supersedes_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_identity_resolution_evidence: {
        Row: {
          bridge_from_publisher_source_id: string | null
          bridge_to_publisher_source_id: string | null
          candidate_id: string | null
          case_id: string
          created_at: string
          evidence_kind: string
          evidence_summary: string
          evidence_url: string | null
          id: string
          is_conflicting: boolean
          observed_at: string | null
          observed_payload: Json
          publisher_source_id: string | null
          recorded_by_decision_id: string | null
          recorded_by_user_id: string | null
          source_url_scope_version_id: string | null
          visibility: string
        }
        Insert: {
          bridge_from_publisher_source_id?: string | null
          bridge_to_publisher_source_id?: string | null
          candidate_id?: string | null
          case_id: string
          created_at?: string
          evidence_kind: string
          evidence_summary: string
          evidence_url?: string | null
          id?: string
          is_conflicting?: boolean
          observed_at?: string | null
          observed_payload?: Json
          publisher_source_id?: string | null
          recorded_by_decision_id?: string | null
          recorded_by_user_id?: string | null
          source_url_scope_version_id?: string | null
          visibility: string
        }
        Update: {
          bridge_from_publisher_source_id?: string | null
          bridge_to_publisher_source_id?: string | null
          candidate_id?: string | null
          case_id?: string
          created_at?: string
          evidence_kind?: string
          evidence_summary?: string
          evidence_url?: string | null
          id?: string
          is_conflicting?: boolean
          observed_at?: string | null
          observed_payload?: Json
          publisher_source_id?: string | null
          recorded_by_decision_id?: string | null
          recorded_by_user_id?: string | null
          source_url_scope_version_id?: string | null
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_from_publisher_source_fkey"
            columns: ["bridge_from_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_from_publisher_source_fkey"
            columns: ["bridge_from_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_from_publisher_source_fkey"
            columns: ["bridge_from_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_from_publisher_source_fkey"
            columns: ["bridge_from_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_from_publisher_source_fkey"
            columns: ["bridge_from_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_to_publisher_source_i_fkey"
            columns: ["bridge_to_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_to_publisher_source_i_fkey"
            columns: ["bridge_to_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_to_publisher_source_i_fkey"
            columns: ["bridge_to_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_to_publisher_source_i_fkey"
            columns: ["bridge_to_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evid_bridge_to_publisher_source_i_fkey"
            columns: ["bridge_to_publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evide_source_url_scope_version_id_fkey"
            columns: ["source_url_scope_version_id"]
            isOneToOne: false
            referencedRelation: "trusted_source_url_scope_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_candidate_id_fkey"
            columns: ["candidate_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_case_id_fkey"
            columns: ["case_id"]
            isOneToOne: false
            referencedRelation: "news_identity_review_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_evidence_kind_fkey"
            columns: ["evidence_kind"]
            isOneToOne: false
            referencedRelation: "news_identity_evidence_kinds"
            referencedColumns: ["evidence_kind"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_evidence_recorded_by_decision_id_fkey"
            columns: ["recorded_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_identity_resolution_rules: {
        Row: {
          active: boolean
          created_at: string
          display_name: string
          rule_definition: Json
          rule_key: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          display_name: string
          rule_definition: Json
          rule_key: string
        }
        Update: {
          active?: boolean
          created_at?: string
          display_name?: string
          rule_definition?: Json
          rule_key?: string
        }
        Relationships: []
      }
      news_item_classification_versions: {
        Row: {
          classification_id: string
          closed_by_decision_id: string | null
          competition_edition_id: string | null
          competition_id: string | null
          created_at: string
          decision_id: string
          id: string
          is_current: boolean
          primary_evidence_id: string
          recorded_from: string
          recorded_to: string | null
          sport_id: string | null
          superseded_at: string | null
          supersedes_classification_version_id: string | null
          target_type: string
          team_id: string | null
        }
        Insert: {
          classification_id: string
          closed_by_decision_id?: string | null
          competition_edition_id?: string | null
          competition_id?: string | null
          created_at?: string
          decision_id: string
          id?: string
          is_current?: boolean
          primary_evidence_id: string
          recorded_from: string
          recorded_to?: string | null
          sport_id?: string | null
          superseded_at?: string | null
          supersedes_classification_version_id?: string | null
          target_type: string
          team_id?: string | null
        }
        Update: {
          classification_id?: string
          closed_by_decision_id?: string | null
          competition_edition_id?: string | null
          competition_id?: string | null
          created_at?: string
          decision_id?: string
          id?: string
          is_current?: boolean
          primary_evidence_id?: string
          recorded_from?: string
          recorded_to?: string | null
          sport_id?: string | null
          superseded_at?: string | null
          supersedes_classification_version_id?: string | null
          target_type?: string
          team_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_item_classification_vers_supersedes_classification_ve_fkey"
            columns: ["supersedes_classification_version_id"]
            isOneToOne: false
            referencedRelation: "news_item_classification_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_classification_id_fkey"
            columns: ["classification_id"]
            isOneToOne: false
            referencedRelation: "news_item_classifications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_competition_edition_id_fkey"
            columns: ["competition_edition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_competition_edition_id_fkey"
            columns: ["competition_edition_id"]
            isOneToOne: false
            referencedRelation: "competition_edition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "competition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_primary_evidence_id_fkey"
            columns: ["primary_evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "news_item_classification_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      news_item_classifications: {
        Row: {
          classification_id: string
          created_at: string
          created_by_decision_id: string
          id: string
          news_item_id: string
        }
        Insert: {
          classification_id?: string
          created_at?: string
          created_by_decision_id: string
          id?: string
          news_item_id: string
        }
        Update: {
          classification_id?: string
          created_at?: string
          created_by_decision_id?: string
          id?: string
          news_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_item_classifications_created_by_decision_id_fkey"
            columns: ["created_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classifications_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classifications_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classifications_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_classifications_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
        ]
      }
      news_item_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          decision_id: string
          headline: string
          id: string
          is_current: boolean
          news_item_id: string
          publication_state: string
          publication_time: string | null
          publication_time_evidence_id: string | null
          recorded_from: string
          recorded_to: string | null
          summary: string | null
          superseded_at: string | null
          supersedes_version_id: string | null
          version_number: number
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id: string
          headline: string
          id?: string
          is_current?: boolean
          news_item_id: string
          publication_state: string
          publication_time?: string | null
          publication_time_evidence_id?: string | null
          recorded_from: string
          recorded_to?: string | null
          summary?: string | null
          superseded_at?: string | null
          supersedes_version_id?: string | null
          version_number: number
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id?: string
          headline?: string
          id?: string
          is_current?: boolean
          news_item_id?: string
          publication_state?: string
          publication_time?: string | null
          publication_time_evidence_id?: string | null
          recorded_from?: string
          recorded_to?: string | null
          summary?: string | null
          superseded_at?: string | null
          supersedes_version_id?: string | null
          version_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "news_item_versions_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_versions_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_versions_publication_time_evidence_id_fkey"
            columns: ["publication_time_evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_versions_supersedes_version_id_fkey"
            columns: ["supersedes_version_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["item_version_id"]
          },
          {
            foreignKeyName: "news_item_versions_supersedes_version_id_fkey"
            columns: ["supersedes_version_id"]
            isOneToOne: false
            referencedRelation: "news_item_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_item_versions_supersedes_version_id_fkey"
            columns: ["supersedes_version_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["item_version_id"]
          },
          {
            foreignKeyName: "news_item_versions_supersedes_version_id_fkey"
            columns: ["supersedes_version_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["item_version_id"]
          },
        ]
      }
      news_items: {
        Row: {
          created_at: string
          created_by_decision_id: string
          id: string
          item_kind: string
          news_item_id: string
        }
        Insert: {
          created_at?: string
          created_by_decision_id: string
          id?: string
          item_kind: string
          news_item_id?: string
        }
        Update: {
          created_at?: string
          created_by_decision_id?: string
          id?: string
          item_kind?: string
          news_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_items_created_by_decision_id_fkey"
            columns: ["created_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_manifestation_assignment_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          decision_id: string
          id: string
          is_current: boolean
          manifestation_id: string
          news_item_id: string
          primary_evidence_id: string
          recorded_from: string
          recorded_to: string | null
          superseded_at: string | null
          supersedes_assignment_id: string | null
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id: string
          id?: string
          is_current?: boolean
          manifestation_id: string
          news_item_id: string
          primary_evidence_id: string
          recorded_from: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_assignment_id?: string | null
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id?: string
          id?: string
          is_current?: boolean
          manifestation_id?: string
          news_item_id?: string
          primary_evidence_id?: string
          recorded_from?: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_assignment_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_manifestation_assignment_ver_supersedes_assignment_id_fkey"
            columns: ["supersedes_assignment_id"]
            isOneToOne: false
            referencedRelation: "news_manifestation_assignment_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versio_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_manifestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_assignment_versions_primary_evidence_id_fkey"
            columns: ["primary_evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
        ]
      }
      news_manifestation_urls: {
        Row: {
          created_at: string
          created_by_decision_id: string
          id: string
          is_public_destination: boolean
          manifestation_id: string
          manifestation_url_id: string
          normalized_url: string
          primary_evidence_id: string
          url: string
          url_kind: string
        }
        Insert: {
          created_at?: string
          created_by_decision_id: string
          id?: string
          is_public_destination?: boolean
          manifestation_id: string
          manifestation_url_id?: string
          normalized_url: string
          primary_evidence_id: string
          url: string
          url_kind: string
        }
        Update: {
          created_at?: string
          created_by_decision_id?: string
          id?: string
          is_public_destination?: boolean
          manifestation_id?: string
          manifestation_url_id?: string
          normalized_url?: string
          primary_evidence_id?: string
          url?: string
          url_kind?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_manifestation_urls_created_by_decision_id_fkey"
            columns: ["created_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_urls_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_manifestation_urls_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_manifestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestation_urls_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_manifestation_urls_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_manifestation_urls_primary_evidence_id_fkey"
            columns: ["primary_evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
        ]
      }
      news_manifestations: {
        Row: {
          created_at: string
          created_by_decision_id: string
          first_observed_at: string
          id: string
          manifestation_id: string
          manifestation_kind: string
          primary_evidence_id: string
          publisher_source_id: string
          source_reference: string | null
        }
        Insert: {
          created_at?: string
          created_by_decision_id: string
          first_observed_at: string
          id?: string
          manifestation_id?: string
          manifestation_kind: string
          primary_evidence_id: string
          publisher_source_id: string
          source_reference?: string | null
        }
        Update: {
          created_at?: string
          created_by_decision_id?: string
          first_observed_at?: string
          id?: string
          manifestation_id?: string
          manifestation_kind?: string
          primary_evidence_id?: string
          publisher_source_id?: string
          source_reference?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_manifestations_created_by_decision_id_fkey"
            columns: ["created_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestations_primary_evidence_id_fkey"
            columns: ["primary_evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_manifestations_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_manifestations_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_manifestations_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_manifestations_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_manifestations_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      news_official_team_publication_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          effective_from: string | null
          effective_to: string | null
          id: string
          is_current: boolean
          notes: string | null
          organizational_contributor_id: string | null
          publisher_source_id: string
          relationship_type: string
          resolution_decision_id: string | null
          superseded_at: string | null
          team_id: string
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          organizational_contributor_id?: string | null
          publisher_source_id: string
          relationship_type: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
          team_id: string
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          organizational_contributor_id?: string | null
          publisher_source_id?: string
          relationship_type?: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
          team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_official_team_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_official_team_publicatio_organizational_contributor_i_fkey"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_official_team_publication_version_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_official_team_publication_version_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_official_team_publication_version_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_official_team_publication_version_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_official_team_publication_version_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_official_team_publication_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_official_team_publication_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "news_official_team_publication_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "news_official_team_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_organizational_contributor_alias_versions: {
        Row: {
          alias: string
          closed_by_decision_id: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          normalized_alias: string | null
          organizational_contributor_id: string
          resolution_decision_id: string | null
          superseded_at: string | null
        }
        Insert: {
          alias: string
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_alias?: string | null
          organizational_contributor_id: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Update: {
          alias?: string
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_alias?: string | null
          organizational_contributor_id?: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_org_alias_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_org_alias_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_organizational_contribu_organizational_contributor_i_fkey1"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
        ]
      }
      news_organizational_contributor_identifiers: {
        Row: {
          created_at: string
          id: string
          identifier: string
          namespace: string
          organizational_contributor_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          identifier: string
          namespace: string
          organizational_contributor_id: string
        }
        Update: {
          created_at?: string
          id?: string
          identifier?: string
          namespace?: string
          organizational_contributor_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_organizational_contribu_organizational_contributor_i_fkey2"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
        ]
      }
      news_organizational_contributor_versions: {
        Row: {
          active: boolean
          closed_by_decision_id: string | null
          created_at: string
          display_name: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          normalized_name: string | null
          organizational_contributor_id: string
          resolution_decision_id: string | null
          superseded_at: string | null
        }
        Insert: {
          active?: boolean
          closed_by_decision_id?: string | null
          created_at?: string
          display_name: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_name?: string | null
          organizational_contributor_id: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Update: {
          active?: boolean
          closed_by_decision_id?: string | null
          created_at?: string
          display_name?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_name?: string | null
          organizational_contributor_id?: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_org_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_org_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_organizational_contribut_organizational_contributor_i_fkey"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
        ]
      }
      news_organizational_contributors: {
        Row: {
          contributor_id: string
          created_at: string
          id: string
        }
        Insert: {
          contributor_id?: string
          created_at?: string
          id?: string
        }
        Update: {
          contributor_id?: string
          created_at?: string
          id?: string
        }
        Relationships: []
      }
      news_outbound_open_events: {
        Row: {
          id: string
          manifestation_url_id: string
          news_item_id: string
          opened_at: string
          outbound_open_id: string
          representative_destination_version_id: string
          viewer_user_id: string | null
        }
        Insert: {
          id?: string
          manifestation_url_id: string
          news_item_id: string
          opened_at?: string
          outbound_open_id?: string
          representative_destination_version_id: string
          viewer_user_id?: string | null
        }
        Update: {
          id?: string
          manifestation_url_id?: string
          news_item_id?: string
          opened_at?: string
          outbound_open_id?: string
          representative_destination_version_id?: string
          viewer_user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_outbound_open_events_manifestation_url_id_fkey"
            columns: ["manifestation_url_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_url_id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_manifestation_url_id_fkey"
            columns: ["manifestation_url_id"]
            isOneToOne: false
            referencedRelation: "news_manifestation_urls"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_manifestation_url_id_fkey"
            columns: ["manifestation_url_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_url_id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_manifestation_url_id_fkey"
            columns: ["manifestation_url_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_url_id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_representative_destination_versi_fkey"
            columns: ["representative_destination_version_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["representative_destination_version_id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_representative_destination_versi_fkey"
            columns: ["representative_destination_version_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["representative_destination_version_id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_representative_destination_versi_fkey"
            columns: ["representative_destination_version_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["representative_destination_version_id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_representative_destination_versi_fkey"
            columns: ["representative_destination_version_id"]
            isOneToOne: false
            referencedRelation: "news_representative_destination_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_outbound_open_events_viewer_user_id_fkey"
            columns: ["viewer_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      news_person_pair_state_periods: {
        Row: {
          canonical_person_id: string | null
          closed_by_decision_id: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          opened_by_decision_id: string
          person_a_id: string
          person_b_id: string
          state: string
          superseded_at: string | null
        }
        Insert: {
          canonical_person_id?: string | null
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          opened_by_decision_id: string
          person_a_id: string
          person_b_id: string
          state: string
          superseded_at?: string | null
        }
        Update: {
          canonical_person_id?: string | null
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          opened_by_decision_id?: string
          person_a_id?: string
          person_b_id?: string
          state?: string
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_person_pair_state_periods_canonical_person_id_fkey"
            columns: ["canonical_person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_person_pair_state_periods_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_person_pair_state_periods_opened_by_decision_id_fkey"
            columns: ["opened_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_person_pair_state_periods_person_a_id_fkey"
            columns: ["person_a_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_person_pair_state_periods_person_b_id_fkey"
            columns: ["person_b_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
        ]
      }
      news_person_publisher_relationship_types: {
        Row: {
          active: boolean
          display_name: string
          relationship_type: string
        }
        Insert: {
          active?: boolean
          display_name: string
          relationship_type: string
        }
        Update: {
          active?: boolean
          display_name?: string
          relationship_type?: string
        }
        Relationships: []
      }
      news_person_publisher_relationship_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          effective_from: string | null
          effective_to: string | null
          id: string
          is_current: boolean
          notes: string | null
          person_id: string
          publisher_source_id: string
          relationship_type: string
          resolution_decision_id: string | null
          superseded_at: string | null
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          person_id: string
          publisher_source_id: string
          relationship_type: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          person_id?: string
          publisher_source_id?: string
          relationship_type?: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_person_publisher_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_person_publisher_relationship_ver_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_person_publisher_relationship_ver_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_person_publisher_relationship_ver_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_person_publisher_relationship_ver_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_person_publisher_relationship_ver_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_person_publisher_relationship_versi_relationship_type_fkey"
            columns: ["relationship_type"]
            isOneToOne: false
            referencedRelation: "news_person_publisher_relationship_types"
            referencedColumns: ["relationship_type"]
          },
          {
            foreignKeyName: "news_person_publisher_relationship_versions_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_person_publisher_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      news_phase4_configuration_decisions: {
        Row: {
          action: string
          decided_at: string
          decided_by_actor_id: string | null
          decided_by_user_id: string
          id: string
          notes: string
        }
        Insert: {
          action: string
          decided_at?: string
          decided_by_actor_id?: string | null
          decided_by_user_id: string
          id?: string
          notes: string
        }
        Update: {
          action?: string
          decided_at?: string
          decided_by_actor_id?: string | null
          decided_by_user_id?: string
          id?: string
          notes?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_phase4_configuration_decisions_decided_by_actor_id_fkey"
            columns: ["decided_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
        ]
      }
      news_podcast_episodes: {
        Row: {
          created_at: string
          created_by_decision_id: string
          episode_identifier: string | null
          news_item_id: string
          show_id: string
        }
        Insert: {
          created_at?: string
          created_by_decision_id: string
          episode_identifier?: string | null
          news_item_id: string
          show_id: string
        }
        Update: {
          created_at?: string
          created_by_decision_id?: string
          episode_identifier?: string | null
          news_item_id?: string
          show_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_podcast_episodes_created_by_decision_id_fkey"
            columns: ["created_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_podcast_episodes_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: true
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_podcast_episodes_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: true
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_podcast_episodes_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: true
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_podcast_episodes_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: true
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_podcast_episodes_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_publisher_contributor_profile_versions: {
        Row: {
          closed_by_decision_id: string | null
          contributor_profile_id: string
          created_at: string
          display_name: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          organizational_contributor_id: string | null
          person_id: string | null
          profile_url: string | null
          resolution_decision_id: string | null
          superseded_at: string | null
        }
        Insert: {
          closed_by_decision_id?: string | null
          contributor_profile_id: string
          created_at?: string
          display_name: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          organizational_contributor_id?: string | null
          person_id?: string | null
          profile_url?: string | null
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Update: {
          closed_by_decision_id?: string | null
          contributor_profile_id?: string
          created_at?: string
          display_name?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          organizational_contributor_id?: string | null
          person_id?: string | null
          profile_url?: string | null
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_contributor_profile_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_contributor_profile_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_publisher_contributor_pr_organizational_contributor_i_fkey"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_publisher_contributor_profile__contributor_profile_id_fkey"
            columns: ["contributor_profile_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_contributor_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_publisher_contributor_profile_versions_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
        ]
      }
      news_publisher_contributor_profiles: {
        Row: {
          contributor_profile_id: string
          created_at: string
          created_by_decision_id: string | null
          id: string
          publisher_source_id: string
        }
        Insert: {
          contributor_profile_id?: string
          created_at?: string
          created_by_decision_id?: string | null
          id?: string
          publisher_source_id: string
        }
        Update: {
          contributor_profile_id?: string
          created_at?: string
          created_by_decision_id?: string | null
          id?: string
          publisher_source_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_publisher_contributor_profiles_created_by_decision_id_fkey"
            columns: ["created_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_publisher_contributor_profiles_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_publisher_contributor_profiles_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_publisher_contributor_profiles_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_publisher_contributor_profiles_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_publisher_contributor_profiles_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      news_publisher_policy_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          news_status: string
          notes: string | null
          publisher_source_id: string
          resolution_decision_id: string | null
          superseded_at: string | null
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          news_status: string
          notes?: string | null
          publisher_source_id: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          news_status?: string
          notes?: string | null
          publisher_source_id?: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_publisher_policy_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_publisher_policy_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_publisher_policy_versions_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_publisher_policy_versions_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_publisher_policy_versions_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_publisher_policy_versions_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_publisher_policy_versions_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      news_remote_preview_policy_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          decision_id: string
          id: string
          is_current: boolean
          preview_reference_id: string
          primary_evidence_id: string
          publisher_policy_state: string
          recorded_from: string
          recorded_to: string | null
          superseded_at: string | null
          supersedes_policy_version_id: string | null
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id: string
          id?: string
          is_current?: boolean
          preview_reference_id: string
          primary_evidence_id: string
          publisher_policy_state: string
          recorded_from: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_policy_version_id?: string | null
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id?: string
          id?: string
          is_current?: boolean
          preview_reference_id?: string
          primary_evidence_id?: string
          publisher_policy_state?: string
          recorded_from?: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_policy_version_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_remote_preview_policy_ve_supersedes_policy_version_id_fkey"
            columns: ["supersedes_policy_version_id"]
            isOneToOne: false
            referencedRelation: "news_remote_preview_policy_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_remote_preview_policy_versions_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_remote_preview_policy_versions_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_remote_preview_policy_versions_preview_reference_id_fkey"
            columns: ["preview_reference_id"]
            isOneToOne: false
            referencedRelation: "news_remote_preview_references"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_remote_preview_policy_versions_primary_evidence_id_fkey"
            columns: ["primary_evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
        ]
      }
      news_remote_preview_references: {
        Row: {
          alt_text: string | null
          created_at: string
          created_by_decision_id: string
          id: string
          manifestation_id: string
          preview_kind: string
          preview_reference_id: string
          remote_url: string
        }
        Insert: {
          alt_text?: string | null
          created_at?: string
          created_by_decision_id: string
          id?: string
          manifestation_id: string
          preview_kind: string
          preview_reference_id?: string
          remote_url: string
        }
        Update: {
          alt_text?: string | null
          created_at?: string
          created_by_decision_id?: string
          id?: string
          manifestation_id?: string
          preview_kind?: string
          preview_reference_id?: string
          remote_url?: string
        }
        Relationships: [
          {
            foreignKeyName: "news_remote_preview_references_created_by_decision_id_fkey"
            columns: ["created_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_remote_preview_references_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_remote_preview_references_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_manifestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_remote_preview_references_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_remote_preview_references_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
        ]
      }
      news_representative_destination_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          decision_id: string
          id: string
          is_current: boolean
          manifestation_id: string
          manifestation_url_id: string
          news_item_id: string
          primary_evidence_id: string
          recorded_from: string
          recorded_to: string | null
          superseded_at: string | null
          supersedes_destination_id: string | null
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id: string
          id?: string
          is_current?: boolean
          manifestation_id: string
          manifestation_url_id: string
          news_item_id: string
          primary_evidence_id: string
          recorded_from: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_destination_id?: string | null
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          decision_id?: string
          id?: string
          is_current?: boolean
          manifestation_id?: string
          manifestation_url_id?: string
          news_item_id?: string
          primary_evidence_id?: string
          recorded_from?: string
          recorded_to?: string | null
          superseded_at?: string | null
          supersedes_destination_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_representative_destination__supersedes_destination_id_fkey"
            columns: ["supersedes_destination_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["representative_destination_version_id"]
          },
          {
            foreignKeyName: "news_representative_destination__supersedes_destination_id_fkey"
            columns: ["supersedes_destination_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["representative_destination_version_id"]
          },
          {
            foreignKeyName: "news_representative_destination__supersedes_destination_id_fkey"
            columns: ["supersedes_destination_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["representative_destination_version_id"]
          },
          {
            foreignKeyName: "news_representative_destination__supersedes_destination_id_fkey"
            columns: ["supersedes_destination_id"]
            isOneToOne: false
            referencedRelation: "news_representative_destination_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_representative_destination_vers_closed_by_decision_id_fkey"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_representative_destination_versi_manifestation_url_id_fkey"
            columns: ["manifestation_url_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_url_id"]
          },
          {
            foreignKeyName: "news_representative_destination_versi_manifestation_url_id_fkey"
            columns: ["manifestation_url_id"]
            isOneToOne: false
            referencedRelation: "news_manifestation_urls"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_representative_destination_versi_manifestation_url_id_fkey"
            columns: ["manifestation_url_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_url_id"]
          },
          {
            foreignKeyName: "news_representative_destination_versi_manifestation_url_id_fkey"
            columns: ["manifestation_url_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_url_id"]
          },
          {
            foreignKeyName: "news_representative_destination_versio_primary_evidence_id_fkey"
            columns: ["primary_evidence_id"]
            isOneToOne: false
            referencedRelation: "news_content_evidence"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_representative_destination_versions_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "news_content_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_representative_destination_versions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_representative_destination_versions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_manifestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_representative_destination_versions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_representative_destination_versions_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_representative_destination_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_representative_destination_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_representative_destination_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_representative_destination_versions_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
        ]
      }
      news_show_contributor_roles: {
        Row: {
          active: boolean
          contributor_role: string
          display_name: string
        }
        Insert: {
          active?: boolean
          contributor_role: string
          display_name: string
        }
        Update: {
          active?: boolean
          contributor_role?: string
          display_name?: string
        }
        Relationships: []
      }
      news_show_publisher_relationship_types: {
        Row: {
          active: boolean
          display_name: string
          relationship_type: string
        }
        Insert: {
          active?: boolean
          display_name: string
          relationship_type: string
        }
        Update: {
          active?: boolean
          display_name?: string
          relationship_type?: string
        }
        Relationships: []
      }
      person_alias_versions: {
        Row: {
          alias: string
          alias_kind: string
          closed_by_decision_id: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          normalized_alias: string | null
          person_id: string
          resolution_decision_id: string | null
          superseded_at: string | null
        }
        Insert: {
          alias: string
          alias_kind?: string
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_alias?: string | null
          person_id: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Update: {
          alias?: string
          alias_kind?: string
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_alias?: string | null
          person_id?: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "person_alias_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "person_alias_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "person_alias_versions_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
        ]
      }
      person_identifiers: {
        Row: {
          created_at: string
          id: string
          identifier: string
          namespace: string
          person_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          identifier: string
          namespace: string
          person_id: string
        }
        Update: {
          created_at?: string
          id?: string
          identifier?: string
          namespace?: string
          person_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "person_identifiers_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
        ]
      }
      person_identity_versions: {
        Row: {
          active: boolean
          closed_by_decision_id: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          name_kind: string
          normalized_name: string | null
          person_id: string
          public_name: string
          resolution_decision_id: string | null
          superseded_at: string | null
        }
        Insert: {
          active?: boolean
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          name_kind?: string
          normalized_name?: string | null
          person_id: string
          public_name: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Update: {
          active?: boolean
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          name_kind?: string
          normalized_name?: string | null
          person_id?: string
          public_name?: string
          resolution_decision_id?: string | null
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "person_identity_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "person_identity_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "person_identity_versions_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
        ]
      }
      podcast_show_alias_versions: {
        Row: {
          alias: string
          closed_by_decision_id: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          normalized_alias: string | null
          resolution_decision_id: string | null
          show_id: string
          superseded_at: string | null
        }
        Insert: {
          alias: string
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_alias?: string | null
          resolution_decision_id?: string | null
          show_id: string
          superseded_at?: string | null
        }
        Update: {
          alias?: string
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_alias?: string | null
          resolution_decision_id?: string | null
          show_id?: string
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "podcast_show_alias_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_alias_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_alias_versions_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      podcast_show_contributor_versions: {
        Row: {
          closed_by_decision_id: string | null
          contributor_role: string
          created_at: string
          effective_from: string | null
          effective_to: string | null
          id: string
          is_current: boolean
          notes: string | null
          person_id: string
          resolution_decision_id: string | null
          show_id: string
          superseded_at: string | null
        }
        Insert: {
          closed_by_decision_id?: string | null
          contributor_role: string
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          person_id: string
          resolution_decision_id?: string | null
          show_id: string
          superseded_at?: string | null
        }
        Update: {
          closed_by_decision_id?: string | null
          contributor_role?: string
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          person_id?: string
          resolution_decision_id?: string | null
          show_id?: string
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "podcast_show_contributor_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_contributor_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_contributor_versions_contributor_role_fkey"
            columns: ["contributor_role"]
            isOneToOne: false
            referencedRelation: "news_show_contributor_roles"
            referencedColumns: ["contributor_role"]
          },
          {
            foreignKeyName: "podcast_show_contributor_versions_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_contributor_versions_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      podcast_show_identifiers: {
        Row: {
          created_at: string
          id: string
          identifier: string
          namespace: string
          show_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          identifier: string
          namespace: string
          show_id: string
        }
        Update: {
          created_at?: string
          id?: string
          identifier?: string
          namespace?: string
          show_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "podcast_show_identifiers_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      podcast_show_identity_versions: {
        Row: {
          active: boolean
          closed_by_decision_id: string | null
          created_at: string
          display_name: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          normalized_name: string | null
          resolution_decision_id: string | null
          show_id: string
          superseded_at: string | null
        }
        Insert: {
          active?: boolean
          closed_by_decision_id?: string | null
          created_at?: string
          display_name: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_name?: string | null
          resolution_decision_id?: string | null
          show_id: string
          superseded_at?: string | null
        }
        Update: {
          active?: boolean
          closed_by_decision_id?: string | null
          created_at?: string
          display_name?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_name?: string | null
          resolution_decision_id?: string | null
          show_id?: string
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "podcast_show_identity_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_identity_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_identity_versions_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      podcast_show_publisher_relationship_versions: {
        Row: {
          closed_by_decision_id: string | null
          created_at: string
          effective_from: string | null
          effective_to: string | null
          id: string
          is_current: boolean
          notes: string | null
          publisher_source_id: string
          relationship_type: string
          resolution_decision_id: string | null
          show_id: string
          superseded_at: string | null
        }
        Insert: {
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          publisher_source_id: string
          relationship_type: string
          resolution_decision_id?: string | null
          show_id: string
          superseded_at?: string | null
        }
        Update: {
          closed_by_decision_id?: string | null
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          publisher_source_id?: string
          relationship_type?: string
          resolution_decision_id?: string | null
          show_id?: string
          superseded_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "podcast_show_publisher_closed_decision_fk"
            columns: ["closed_by_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_publisher_relationship_ve_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "podcast_show_publisher_relationship_ve_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "podcast_show_publisher_relationship_ve_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "podcast_show_publisher_relationship_ve_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "podcast_show_publisher_relationship_ve_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_publisher_relationship_vers_relationship_type_fkey"
            columns: ["relationship_type"]
            isOneToOne: false
            referencedRelation: "news_show_publisher_relationship_types"
            referencedColumns: ["relationship_type"]
          },
          {
            foreignKeyName: "podcast_show_publisher_relationship_versions_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "podcast_show_publisher_resolution_decision_fk"
            columns: ["resolution_decision_id"]
            isOneToOne: false
            referencedRelation: "news_identity_resolution_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      podcast_shows: {
        Row: {
          created_at: string
          id: string
          show_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          show_id?: string
        }
        Update: {
          created_at?: string
          id?: string
          show_id?: string
        }
        Relationships: []
      }
      profile_photos: {
        Row: {
          created_at: string
          display_path: string
          focal_x: number
          focal_y: number
          id: string
          source_filename: string
          source_height: number
          source_media_type: string
          source_path: string
          source_width: number
          updated_at: string
          user_id: string
          zoom: number
        }
        Insert: {
          created_at?: string
          display_path: string
          focal_x?: number
          focal_y?: number
          id?: string
          source_filename: string
          source_height: number
          source_media_type: string
          source_path: string
          source_width: number
          updated_at?: string
          user_id: string
          zoom?: number
        }
        Update: {
          created_at?: string
          display_path?: string
          focal_x?: number
          focal_y?: number
          id?: string
          source_filename?: string
          source_height?: number
          source_media_type?: string
          source_path?: string
          source_width?: number
          updated_at?: string
          user_id?: string
          zoom?: number
        }
        Relationships: [
          {
            foreignKeyName: "profile_photos_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      profile_visual_images: {
        Row: {
          created_at: string
          display_path: string
          focal_x: number
          focal_y: number
          id: string
          source_filename: string
          source_height: number
          source_media_type: string
          source_path: string
          source_width: number
          updated_at: string
          user_id: string
          variant: string
          zoom: number
        }
        Insert: {
          created_at?: string
          display_path: string
          focal_x?: number
          focal_y?: number
          id?: string
          source_filename: string
          source_height: number
          source_media_type: string
          source_path: string
          source_width: number
          updated_at?: string
          user_id: string
          variant: string
          zoom?: number
        }
        Update: {
          created_at?: string
          display_path?: string
          focal_x?: number
          focal_y?: number
          id?: string
          source_filename?: string
          source_height?: number
          source_media_type?: string
          source_path?: string
          source_width?: number
          updated_at?: string
          user_id?: string
          variant?: string
          zoom?: number
        }
        Relationships: [
          {
            foreignKeyName: "profile_visual_images_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      profile_visuals: {
        Row: {
          created_at: string
          display_path: string
          focal_x: number
          focal_y: number
          source_filename: string
          source_height: number
          source_media_type: string
          source_path: string
          source_width: number
          updated_at: string
          user_id: string
          variant: string
          zoom: number
        }
        Insert: {
          created_at?: string
          display_path: string
          focal_x?: number
          focal_y?: number
          source_filename: string
          source_height: number
          source_media_type: string
          source_path: string
          source_width: number
          updated_at?: string
          user_id: string
          variant: string
          zoom?: number
        }
        Update: {
          created_at?: string
          display_path?: string
          focal_x?: number
          focal_y?: number
          source_filename?: string
          source_height?: number
          source_media_type?: string
          source_path?: string
          source_width?: number
          updated_at?: string
          user_id?: string
          variant?: string
          zoom?: number
        }
        Relationships: [
          {
            foreignKeyName: "profile_visuals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      profiles: {
        Row: {
          active_profile_photo_id: string | null
          avatar_customization: Json
          avatar_path: string | null
          birthplace: string | null
          created_at: string
          display_name: string
          fanatical_name: string | null
          featured_fan_photo_category: string
          given_name: string | null
          handle: string
          height: string | null
          jersey_number: string | null
          media_namespace: string
          nickname: string | null
          personal_field_visibility: Json
          personalization: Json
          primary_profile_text: string | null
          profile_text_position: Json
          secondary_profile_text: string | null
          tagline: string | null
          updated_at: string
          user_id: string
          visibility: string
          weight: string | null
        }
        Insert: {
          active_profile_photo_id?: string | null
          avatar_customization?: Json
          avatar_path?: string | null
          birthplace?: string | null
          created_at?: string
          display_name?: string
          fanatical_name?: string | null
          featured_fan_photo_category?: string
          given_name?: string | null
          handle?: string
          height?: string | null
          jersey_number?: string | null
          media_namespace?: string
          nickname?: string | null
          personal_field_visibility?: Json
          personalization?: Json
          primary_profile_text?: string | null
          profile_text_position?: Json
          secondary_profile_text?: string | null
          tagline?: string | null
          updated_at?: string
          user_id: string
          visibility?: string
          weight?: string | null
        }
        Update: {
          active_profile_photo_id?: string | null
          avatar_customization?: Json
          avatar_path?: string | null
          birthplace?: string | null
          created_at?: string
          display_name?: string
          fanatical_name?: string | null
          featured_fan_photo_category?: string
          given_name?: string | null
          handle?: string
          height?: string | null
          jersey_number?: string | null
          media_namespace?: string
          nickname?: string | null
          personal_field_visibility?: Json
          personalization?: Json
          primary_profile_text?: string | null
          profile_text_position?: Json
          secondary_profile_text?: string | null
          tagline?: string | null
          updated_at?: string
          user_id?: string
          visibility?: string
          weight?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_active_profile_photo_id_fkey"
            columns: ["active_profile_photo_id"]
            isOneToOne: false
            referencedRelation: "profile_photos"
            referencedColumns: ["id"]
          },
        ]
      }
      source_applicability_versions: {
        Row: {
          applicability_kind: string
          created_at: string
          data_type: string
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          league_id: string | null
          notes: string | null
          review_status: string
          reviewed_by_actor_id: string | null
          source_id: string
          sport_id: string | null
          team_id: string | null
        }
        Insert: {
          applicability_kind: string
          created_at?: string
          data_type: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          league_id?: string | null
          notes?: string | null
          review_status?: string
          reviewed_by_actor_id?: string | null
          source_id: string
          sport_id?: string | null
          team_id?: string | null
        }
        Update: {
          applicability_kind?: string
          created_at?: string
          data_type?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          league_id?: string | null
          notes?: string | null
          review_status?: string
          reviewed_by_actor_id?: string | null
          source_id?: string
          sport_id?: string | null
          team_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "source_applicability_versions_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "catalog_leagues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_applicability_versions_reviewed_by_actor_id_fkey"
            columns: ["reviewed_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_applicability_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_applicability_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_applicability_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_applicability_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_applicability_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_applicability_versions_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_applicability_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_applicability_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "source_applicability_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      source_independence_group_assignment_versions: {
        Row: {
          assigned_by_actor_id: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          independence_group_id: string | null
          is_current: boolean
          notes: string | null
          review_status: string
          source_id: string
        }
        Insert: {
          assigned_by_actor_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          independence_group_id?: string | null
          is_current?: boolean
          notes?: string | null
          review_status: string
          source_id: string
        }
        Update: {
          assigned_by_actor_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          independence_group_id?: string | null
          is_current?: boolean
          notes?: string | null
          review_status?: string
          source_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_independence_group_assignment__assigned_by_actor_id_fkey"
            columns: ["assigned_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_independence_group_assignment_independence_group_id_fkey"
            columns: ["independence_group_id"]
            isOneToOne: false
            referencedRelation: "source_independence_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_independence_group_assignment_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_independence_group_assignment_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_independence_group_assignment_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_independence_group_assignment_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_independence_group_assignment_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      source_independence_groups: {
        Row: {
          created_at: string
          display_name: string
          group_id: string
          id: string
          notes: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_name: string
          group_id: string
          id?: string
          notes?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_name?: string
          group_id?: string
          id?: string
          notes?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      source_qualification_attempts: {
        Row: {
          actor_id: string
          attempt_number: number
          claimed_at: string
          ended_at: string | null
          failure_category: string | null
          failure_reason: string | null
          id: string
          last_heartbeat_at: string
          lease_expires_at: string
          lease_token: string
          outcome: string | null
          work_item_id: string
        }
        Insert: {
          actor_id: string
          attempt_number: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at: string
          lease_token: string
          outcome?: string | null
          work_item_id: string
        }
        Update: {
          actor_id?: string
          attempt_number?: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at?: string
          lease_token?: string
          outcome?: string | null
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_qualification_attempts_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_attempts_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      source_qualification_enrollments: {
        Row: {
          assessed_case_count: number
          contradiction_count: number
          current_policy_id: string
          data_type: string
          enrolled_at: string
          id: string
          latest_evaluation_id: string | null
          match_count: number
          qualification_status: string
          raw_match_rate: number | null
          source_id: string
          updated_at: string
        }
        Insert: {
          assessed_case_count?: number
          contradiction_count?: number
          current_policy_id: string
          data_type: string
          enrolled_at?: string
          id?: string
          latest_evaluation_id?: string | null
          match_count?: number
          qualification_status?: string
          raw_match_rate?: number | null
          source_id: string
          updated_at?: string
        }
        Update: {
          assessed_case_count?: number
          contradiction_count?: number
          current_policy_id?: string
          data_type?: string
          enrolled_at?: string
          id?: string
          latest_evaluation_id?: string | null
          match_count?: number
          qualification_status?: string
          raw_match_rate?: number | null
          source_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_qualification_enrollments_current_policy_id_fkey"
            columns: ["current_policy_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_policies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_enrollments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_enrollments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_enrollments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_enrollments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_enrollments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_latest_evaluation_fk"
            columns: ["latest_evaluation_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_evaluations"
            referencedColumns: ["id"]
          },
        ]
      }
      source_qualification_evaluations: {
        Row: {
          applicable_subject_count: number | null
          assessed_case_count: number
          contradiction_count: number
          decision_basis: string
          enrollment_id: string
          evaluated_at: string
          evaluation_input_key: string
          evaluation_kind: string
          id: string
          match_count: number
          policy_id: string
          prior_status: string
          raw_match_rate: number | null
          resulting_status: string
          tested_applicable_subject_count: number | null
        }
        Insert: {
          applicable_subject_count?: number | null
          assessed_case_count: number
          contradiction_count: number
          decision_basis: string
          enrollment_id: string
          evaluated_at?: string
          evaluation_input_key?: string
          evaluation_kind: string
          id?: string
          match_count: number
          policy_id: string
          prior_status: string
          raw_match_rate?: number | null
          resulting_status: string
          tested_applicable_subject_count?: number | null
        }
        Update: {
          applicable_subject_count?: number | null
          assessed_case_count?: number
          contradiction_count?: number
          decision_basis?: string
          enrollment_id?: string
          evaluated_at?: string
          evaluation_input_key?: string
          evaluation_kind?: string
          id?: string
          match_count?: number
          policy_id?: string
          prior_status?: string
          raw_match_rate?: number | null
          resulting_status?: string
          tested_applicable_subject_count?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "source_qualification_evaluations_enrollment_id_fkey"
            columns: ["enrollment_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_enrollments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_evaluations_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_policies"
            referencedColumns: ["id"]
          },
        ]
      }
      source_qualification_observations: {
        Row: {
          enrollment_id: string
          id: string
          observed_at: string
          outcome: string
          reference_id: string
          reference_result_snapshot: Json
          subject_id: string
          subject_type: string
          tested_applicability_version_id: string
          tested_claim_snapshot: Json
          tested_information_lineage_root_id: string
          tested_information_lineage_version_id: string
          tested_result_id: string
          tested_source_id: string
        }
        Insert: {
          enrollment_id: string
          id?: string
          observed_at?: string
          outcome: string
          reference_id: string
          reference_result_snapshot: Json
          subject_id: string
          subject_type: string
          tested_applicability_version_id: string
          tested_claim_snapshot: Json
          tested_information_lineage_root_id: string
          tested_information_lineage_version_id: string
          tested_result_id: string
          tested_source_id: string
        }
        Update: {
          enrollment_id?: string
          id?: string
          observed_at?: string
          outcome?: string
          reference_id?: string
          reference_result_snapshot?: Json
          subject_id?: string
          subject_type?: string
          tested_applicability_version_id?: string
          tested_claim_snapshot?: Json
          tested_information_lineage_root_id?: string
          tested_information_lineage_version_id?: string
          tested_result_id?: string
          tested_source_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_qualification_observat_tested_applicability_version_fkey"
            columns: ["tested_applicability_version_id"]
            isOneToOne: false
            referencedRelation: "source_applicability_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_observat_tested_information_lineage_r_fkey"
            columns: ["tested_information_lineage_root_id"]
            isOneToOne: false
            referencedRelation: "information_lineages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_observat_tested_information_lineage_v_fkey"
            columns: ["tested_information_lineage_version_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_observations_enrollment_id_fkey"
            columns: ["enrollment_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_enrollments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_observations_reference_id_fkey"
            columns: ["reference_id"]
            isOneToOne: true
            referencedRelation: "source_qualification_references"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_observations_tested_result_id_fkey"
            columns: ["tested_result_id"]
            isOneToOne: true
            referencedRelation: "source_qualification_results"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_observations_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_observations_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_observations_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_observations_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_observations_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      source_qualification_policies: {
        Row: {
          active: boolean
          configuration: Json
          created_at: string
          data_type: string
          first_decision_case_count: number
          first_rating_case_count: number
          id: string
          is_current: boolean
          minimum_reference_information_lineages: number
          policy_key: string
          probationary_rate: number
          qualification_rate: number
          reassessment_case_interval: number
          superseded_at: string | null
          version: number
        }
        Insert: {
          active?: boolean
          configuration?: Json
          created_at?: string
          data_type: string
          first_decision_case_count: number
          first_rating_case_count: number
          id?: string
          is_current?: boolean
          minimum_reference_information_lineages: number
          policy_key: string
          probationary_rate: number
          qualification_rate: number
          reassessment_case_interval: number
          superseded_at?: string | null
          version: number
        }
        Update: {
          active?: boolean
          configuration?: Json
          created_at?: string
          data_type?: string
          first_decision_case_count?: number
          first_rating_case_count?: number
          id?: string
          is_current?: boolean
          minimum_reference_information_lineages?: number
          policy_key?: string
          probationary_rate?: number
          qualification_rate?: number
          reassessment_case_interval?: number
          superseded_at?: string | null
          version?: number
        }
        Relationships: []
      }
      source_qualification_reference_contributions: {
        Row: {
          adjudication_source_contribution_id: string | null
          created_at: string
          id: string
          information_lineage_root_id: string
          information_lineage_version_id: string
          reference_id: string
          result_id: string | null
          source_id: string
        }
        Insert: {
          adjudication_source_contribution_id?: string | null
          created_at?: string
          id?: string
          information_lineage_root_id: string
          information_lineage_version_id: string
          reference_id: string
          result_id?: string | null
          source_id: string
        }
        Update: {
          adjudication_source_contribution_id?: string | null
          created_at?: string
          id?: string
          information_lineage_root_id?: string
          information_lineage_version_id?: string
          reference_id?: string
          result_id?: string | null
          source_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_qualification_referenc_adjudication_source_contribu_fkey"
            columns: ["adjudication_source_contribution_id"]
            isOneToOne: false
            referencedRelation: "catalog_adjudication_source_contributions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_referenc_information_lineage_version__fkey"
            columns: ["information_lineage_version_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_reference_contributions_reference_id_fkey"
            columns: ["reference_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_references"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_reference_contributions_result_id_fkey"
            columns: ["result_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_results"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_reference_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_reference_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_reference_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_reference_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_reference_contributions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_reference_information_lineage_root_id_fkey"
            columns: ["information_lineage_root_id"]
            isOneToOne: false
            referencedRelation: "information_lineages"
            referencedColumns: ["id"]
          },
        ]
      }
      source_qualification_references: {
        Row: {
          authoritative_adjudication_id: string | null
          contributing_information_lineage_count: number
          created_at: string
          data_type: string
          id: string
          non_production: boolean
          normalized_reference_result: Json
          policy_id: string
          reference_kind: string
          subject_id: string
          subject_type: string
          tested_information_lineage_root_id: string
          tested_result_id: string
          tested_source_id: string
        }
        Insert: {
          authoritative_adjudication_id?: string | null
          contributing_information_lineage_count: number
          created_at?: string
          data_type: string
          id?: string
          non_production?: boolean
          normalized_reference_result: Json
          policy_id: string
          reference_kind: string
          subject_id: string
          subject_type: string
          tested_information_lineage_root_id: string
          tested_result_id: string
          tested_source_id: string
        }
        Update: {
          authoritative_adjudication_id?: string | null
          contributing_information_lineage_count?: number
          created_at?: string
          data_type?: string
          id?: string
          non_production?: boolean
          normalized_reference_result?: Json
          policy_id?: string
          reference_kind?: string
          subject_id?: string
          subject_type?: string
          tested_information_lineage_root_id?: string
          tested_result_id?: string
          tested_source_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_qualification_referenc_authoritative_adjudication_i_fkey"
            columns: ["authoritative_adjudication_id"]
            isOneToOne: false
            referencedRelation: "catalog_determinate_adjudications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_referenc_tested_information_lineage_r_fkey"
            columns: ["tested_information_lineage_root_id"]
            isOneToOne: false
            referencedRelation: "information_lineages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_references_policy_id_fkey"
            columns: ["policy_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_policies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_references_tested_result_id_fkey"
            columns: ["tested_result_id"]
            isOneToOne: true
            referencedRelation: "source_qualification_results"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_references_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_references_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_references_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_references_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_references_tested_source_id_fkey"
            columns: ["tested_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      source_qualification_results: {
        Row: {
          applicability_version_id: string
          attempt_id: string
          id: string
          information_lineage_version_id: string
          normalized_result: Json | null
          provenance_summary: string | null
          result_kind: string
          result_payload: Json
          result_schema_version: number
          source_id: string
          source_location: string
          submitted_at: string
          submitted_by_actor_id: string
          work_item_id: string
        }
        Insert: {
          applicability_version_id: string
          attempt_id: string
          id?: string
          information_lineage_version_id: string
          normalized_result?: Json | null
          provenance_summary?: string | null
          result_kind: string
          result_payload: Json
          result_schema_version?: number
          source_id: string
          source_location: string
          submitted_at?: string
          submitted_by_actor_id: string
          work_item_id: string
        }
        Update: {
          applicability_version_id?: string
          attempt_id?: string
          id?: string
          information_lineage_version_id?: string
          normalized_result?: Json | null
          provenance_summary?: string | null
          result_kind?: string
          result_payload?: Json
          result_schema_version?: number
          source_id?: string
          source_location?: string
          submitted_at?: string
          submitted_by_actor_id?: string
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_qualification_results_applicability_version_id_fkey"
            columns: ["applicability_version_id"]
            isOneToOne: false
            referencedRelation: "source_applicability_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_results_attempt_id_fkey"
            columns: ["attempt_id"]
            isOneToOne: true
            referencedRelation: "source_qualification_attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_results_information_lineage_version_i_fkey"
            columns: ["information_lineage_version_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_results_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_results_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_results_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_results_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_qualification_results_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_results_submitted_by_actor_id_fkey"
            columns: ["submitted_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_results_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: true
            referencedRelation: "source_qualification_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      source_qualification_work_events: {
        Row: {
          actor_id: string | null
          attempt_number: number | null
          details: Json
          event_type: string
          id: number
          occurred_at: string
          work_item_id: string
        }
        Insert: {
          actor_id?: string | null
          attempt_number?: number | null
          details?: Json
          event_type: string
          id?: never
          occurred_at?: string
          work_item_id: string
        }
        Update: {
          actor_id?: string | null
          attempt_number?: number | null
          details?: Json
          event_type?: string
          id?: never
          occurred_at?: string
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_qualification_work_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_work_events_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      source_qualification_work_items: {
        Row: {
          accepted_result_id: string | null
          applicability_version_id: string
          assigned_source_location: string
          attempt_count: number
          available_at: string
          capability_scope: Json
          claimed_by_actor_id: string | null
          completed_at: string | null
          created_at: string
          data_type: string
          enrollment_id: string
          failure_category: string | null
          failure_reason: string | null
          id: string
          information_lineage_version_id: string | null
          lease_expires_at: string | null
          lease_token: string | null
          priority: number
          status: string
          subject_id: string
          subject_type: string
          updated_at: string
        }
        Insert: {
          accepted_result_id?: string | null
          applicability_version_id: string
          assigned_source_location: string
          attempt_count?: number
          available_at?: string
          capability_scope?: Json
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          data_type: string
          enrollment_id: string
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          information_lineage_version_id?: string | null
          lease_expires_at?: string | null
          lease_token?: string | null
          priority?: number
          status?: string
          subject_id: string
          subject_type: string
          updated_at?: string
        }
        Update: {
          accepted_result_id?: string | null
          applicability_version_id?: string
          assigned_source_location?: string
          attempt_count?: number
          available_at?: string
          capability_scope?: Json
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          data_type?: string
          enrollment_id?: string
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          information_lineage_version_id?: string | null
          lease_expires_at?: string | null
          lease_token?: string | null
          priority?: number
          status?: string
          subject_id?: string
          subject_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "source_qualification_work_ite_information_lineage_version__fkey"
            columns: ["information_lineage_version_id"]
            isOneToOne: false
            referencedRelation: "information_lineage_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_work_items_applicability_version_id_fkey"
            columns: ["applicability_version_id"]
            isOneToOne: false
            referencedRelation: "source_applicability_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_work_items_claimed_by_actor_id_fkey"
            columns: ["claimed_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_work_items_enrollment_id_fkey"
            columns: ["enrollment_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_enrollments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_qualification_work_result_fk"
            columns: ["accepted_result_id"]
            isOneToOne: false
            referencedRelation: "source_qualification_results"
            referencedColumns: ["id"]
          },
        ]
      }
      source_trust_assignments: {
        Row: {
          assigned_by_actor_id: string | null
          created_at: string
          data_type: string
          effective_from: string | null
          effective_to: string | null
          id: string
          is_current: boolean
          notes: string | null
          source_id: string
          superseded_at: string | null
          trust_tier: number
        }
        Insert: {
          assigned_by_actor_id?: string | null
          created_at?: string
          data_type: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          source_id: string
          superseded_at?: string | null
          trust_tier: number
        }
        Update: {
          assigned_by_actor_id?: string | null
          created_at?: string
          data_type?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          is_current?: boolean
          notes?: string | null
          source_id?: string
          superseded_at?: string | null
          trust_tier?: number
        }
        Relationships: [
          {
            foreignKeyName: "source_trust_assignments_assigned_by_actor_id_fkey"
            columns: ["assigned_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "source_trust_assignments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_trust_assignments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_trust_assignments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_trust_assignments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "source_trust_assignments_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      sports_played: {
        Row: {
          client_key: string
          created_at: string
          highlight: string | null
          id: string
          level: string | null
          position: string | null
          sort_order: number
          sport: string
          updated_at: string
          user_id: string
          years: string | null
        }
        Insert: {
          client_key: string
          created_at?: string
          highlight?: string | null
          id?: string
          level?: string | null
          position?: string | null
          sort_order?: number
          sport?: string
          updated_at?: string
          user_id: string
          years?: string | null
        }
        Update: {
          client_key?: string
          created_at?: string
          highlight?: string | null
          id?: string
          level?: string | null
          position?: string | null
          sort_order?: number
          sport?: string
          updated_at?: string
          user_id?: string
          years?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "sports_played_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      staff_roles: {
        Row: {
          created_at: string
          is_active: boolean
          permissions: string[]
          role: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          is_active?: boolean
          permissions?: string[]
          role: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          is_active?: boolean
          permissions?: string[]
          role?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      team_alias_versions: {
        Row: {
          alias: string
          alias_type: string
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          locale: string | null
          normalized_alias: string | null
          record_status: string
          superseded_at: string | null
          team_id: string
          verification_decision_id: string | null
        }
        Insert: {
          alias: string
          alias_type: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          locale?: string | null
          normalized_alias?: string | null
          record_status: string
          superseded_at?: string | null
          team_id: string
          verification_decision_id?: string | null
        }
        Update: {
          alias?: string
          alias_type?: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          locale?: string | null
          normalized_alias?: string | null
          record_status?: string
          superseded_at?: string | null
          team_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_alias_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_alias_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_alias_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_alias_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_alias_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      team_color_bootstrap_rollout_policies: {
        Row: {
          active: boolean
          cohort_size: number
          created_at: string
          id: string
          is_current: boolean
          policy_key: string
          recheck_trigger: string
          superseded_at: string | null
          trigger_fresh_team_count: number
          version: number
        }
        Insert: {
          active?: boolean
          cohort_size: number
          created_at?: string
          id?: string
          is_current?: boolean
          policy_key: string
          recheck_trigger: string
          superseded_at?: string | null
          trigger_fresh_team_count: number
          version: number
        }
        Update: {
          active?: boolean
          cohort_size?: number
          created_at?: string
          id?: string
          is_current?: boolean
          policy_key?: string
          recheck_trigger?: string
          superseded_at?: string | null
          trigger_fresh_team_count?: number
          version?: number
        }
        Relationships: []
      }
      team_color_bootstrap_rollout_state: {
        Row: {
          fresh_verified_team_count: number
          id: string
          rollout_policy_id: string
          threshold_decision_id: string | null
          threshold_reached_at: string | null
          updated_at: string
        }
        Insert: {
          fresh_verified_team_count?: number
          id?: string
          rollout_policy_id: string
          threshold_decision_id?: string | null
          threshold_reached_at?: string | null
          updated_at?: string
        }
        Update: {
          fresh_verified_team_count?: number
          id?: string
          rollout_policy_id?: string
          threshold_decision_id?: string | null
          threshold_reached_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_color_bootstrap_rollout_state_rollout_policy_id_fkey"
            columns: ["rollout_policy_id"]
            isOneToOne: true
            referencedRelation: "team_color_bootstrap_rollout_policies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_bootstrap_rollout_state_threshold_decision_id_fkey"
            columns: ["threshold_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      team_color_bootstrap_verified_teams: {
        Row: {
          bootstrap_due_at: string | null
          bootstrap_queued_at: string | null
          bootstrap_work_item_id: string | null
          enrolled_at: string
          enrollment_ordinal: number
          first_verification_decision_id: string
          first_verified_version_id: string
          id: string
          is_bootstrap_cohort: boolean
          rollout_policy_id: string
          team_id: string
        }
        Insert: {
          bootstrap_due_at?: string | null
          bootstrap_queued_at?: string | null
          bootstrap_work_item_id?: string | null
          enrolled_at?: string
          enrollment_ordinal: number
          first_verification_decision_id: string
          first_verified_version_id: string
          id?: string
          is_bootstrap_cohort: boolean
          rollout_policy_id: string
          team_id: string
        }
        Update: {
          bootstrap_due_at?: string | null
          bootstrap_queued_at?: string | null
          bootstrap_work_item_id?: string | null
          enrolled_at?: string
          enrollment_ordinal?: number
          first_verification_decision_id?: string
          first_verified_version_id?: string
          id?: string
          is_bootstrap_cohort?: boolean
          rollout_policy_id?: string
          team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_color_bootstrap_verified_first_verification_decision__fkey"
            columns: ["first_verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_bootstrap_verified_te_first_verified_version_id_fkey"
            columns: ["first_verified_version_id"]
            isOneToOne: false
            referencedRelation: "team_color_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_bootstrap_verified_teams_bootstrap_work_item_id_fkey"
            columns: ["bootstrap_work_item_id"]
            isOneToOne: true
            referencedRelation: "team_color_work_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_bootstrap_verified_teams_rollout_policy_id_fkey"
            columns: ["rollout_policy_id"]
            isOneToOne: false
            referencedRelation: "team_color_bootstrap_rollout_policies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_bootstrap_verified_teams_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_bootstrap_verified_teams_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_color_bootstrap_verified_teams_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      team_color_source_candidates: {
        Row: {
          created_at: string
          discovery_summary: string
          evidence_url: string
          id: string
          observed_at: string
          resolution_snapshot: Json
          source_id: string
          source_url_scope_version_id: string | null
          submitted_by_actor_id: string
          work_item_id: string
        }
        Insert: {
          created_at?: string
          discovery_summary: string
          evidence_url: string
          id?: string
          observed_at: string
          resolution_snapshot?: Json
          source_id: string
          source_url_scope_version_id?: string | null
          submitted_by_actor_id: string
          work_item_id: string
        }
        Update: {
          created_at?: string
          discovery_summary?: string
          evidence_url?: string
          id?: string
          observed_at?: string
          resolution_snapshot?: Json
          source_id?: string
          source_url_scope_version_id?: string | null
          submitted_by_actor_id?: string
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_color_source_candidates_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "team_color_source_candidates_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "team_color_source_candidates_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "team_color_source_candidates_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "team_color_source_candidates_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_candidates_source_url_scope_version_id_fkey"
            columns: ["source_url_scope_version_id"]
            isOneToOne: false
            referencedRelation: "trusted_source_url_scope_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_candidates_submitted_by_actor_id_fkey"
            columns: ["submitted_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_candidates_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "team_color_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      team_color_source_reliability_observations: {
        Row: {
          claim_snapshot: Json
          created_at: string
          decided_at: string
          decision_id: string
          evidence_id: string
          evidence_observed_at: string | null
          id: string
          independence_group_id: string
          independent_corroborating_group_count: number
          league_id: string | null
          outcome: string
          proposal_id: string
          source_id: string
          sport_id: string
          team_id: string
          verified_palette: Json | null
        }
        Insert: {
          claim_snapshot: Json
          created_at?: string
          decided_at: string
          decision_id: string
          evidence_id: string
          evidence_observed_at?: string | null
          id?: string
          independence_group_id: string
          independent_corroborating_group_count?: number
          league_id?: string | null
          outcome: string
          proposal_id: string
          source_id: string
          sport_id: string
          team_id: string
          verified_palette?: Json | null
        }
        Update: {
          claim_snapshot?: Json
          created_at?: string
          decided_at?: string
          decision_id?: string
          evidence_id?: string
          evidence_observed_at?: string | null
          id?: string
          independence_group_id?: string
          independent_corroborating_group_count?: number
          league_id?: string | null
          outcome?: string
          proposal_id?: string
          source_id?: string
          sport_id?: string
          team_id?: string
          verified_palette?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "team_color_source_reliability_observ_independence_group_id_fkey"
            columns: ["independence_group_id"]
            isOneToOne: false
            referencedRelation: "source_independence_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_decision_id_fkey"
            columns: ["decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_evidence_id_fkey"
            columns: ["evidence_id"]
            isOneToOne: false
            referencedRelation: "catalog_proposal_evidence"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "catalog_leagues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "catalog_change_proposals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_color_source_reliability_observations_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      team_color_versions: {
        Row: {
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          primary_color: string
          quaternary_color: string | null
          quinary_color: string | null
          record_status: string
          secondary_color: string
          superseded_at: string | null
          team_id: string
          tertiary_color: string | null
          verification_decision_id: string | null
        }
        Insert: {
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          primary_color: string
          quaternary_color?: string | null
          quinary_color?: string | null
          record_status: string
          secondary_color: string
          superseded_at?: string | null
          team_id: string
          tertiary_color?: string | null
          verification_decision_id?: string | null
        }
        Update: {
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          primary_color?: string
          quaternary_color?: string | null
          quinary_color?: string | null
          record_status?: string
          secondary_color?: string
          superseded_at?: string | null
          team_id?: string
          tertiary_color?: string | null
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_color_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_color_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_color_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      team_color_work_attempts: {
        Row: {
          actor_id: string
          attempt_number: number
          claimed_at: string
          ended_at: string | null
          failure_category: string | null
          failure_reason: string | null
          id: string
          last_heartbeat_at: string
          lease_expires_at: string
          lease_token: string
          outcome: string | null
          summary: Json
          work_item_id: string
        }
        Insert: {
          actor_id: string
          attempt_number: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at: string
          lease_token: string
          outcome?: string | null
          summary?: Json
          work_item_id: string
        }
        Update: {
          actor_id?: string
          attempt_number?: number
          claimed_at?: string
          ended_at?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          last_heartbeat_at?: string
          lease_expires_at?: string
          lease_token?: string
          outcome?: string | null
          summary?: Json
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_color_work_attempts_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_work_attempts_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "team_color_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      team_color_work_events: {
        Row: {
          actor_id: string | null
          attempt_number: number | null
          details: Json
          event_type: string
          id: number
          occurred_at: string
          work_item_id: string
        }
        Insert: {
          actor_id?: string | null
          attempt_number?: number | null
          details?: Json
          event_type: string
          id?: never
          occurred_at?: string
          work_item_id: string
        }
        Update: {
          actor_id?: string | null
          attempt_number?: number | null
          details?: Json
          event_type?: string
          id?: never
          occurred_at?: string
          work_item_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_color_work_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_work_events_work_item_id_fkey"
            columns: ["work_item_id"]
            isOneToOne: false
            referencedRelation: "team_color_work_items"
            referencedColumns: ["id"]
          },
        ]
      }
      team_color_work_items: {
        Row: {
          attempt_count: number
          available_at: string
          claimed_at: string | null
          claimed_by_actor_id: string | null
          completed_at: string | null
          created_at: string
          created_by_actor_id: string | null
          created_by_auth_user_id: string | null
          expected_current_color_version_id: string | null
          failure_category: string | null
          failure_reason: string | null
          id: string
          lease_expires_at: string | null
          lease_token: string | null
          outcome_summary: Json
          priority: number
          proposal_id: string | null
          recheck_trigger: string | null
          request_reason: string
          status: string
          team_id: string
          updated_at: string
          work_kind: string
        }
        Insert: {
          attempt_count?: number
          available_at?: string
          claimed_at?: string | null
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          created_by_actor_id?: string | null
          created_by_auth_user_id?: string | null
          expected_current_color_version_id?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          lease_expires_at?: string | null
          lease_token?: string | null
          outcome_summary?: Json
          priority?: number
          proposal_id?: string | null
          recheck_trigger?: string | null
          request_reason: string
          status?: string
          team_id: string
          updated_at?: string
          work_kind: string
        }
        Update: {
          attempt_count?: number
          available_at?: string
          claimed_at?: string | null
          claimed_by_actor_id?: string | null
          completed_at?: string | null
          created_at?: string
          created_by_actor_id?: string | null
          created_by_auth_user_id?: string | null
          expected_current_color_version_id?: string | null
          failure_category?: string | null
          failure_reason?: string | null
          id?: string
          lease_expires_at?: string | null
          lease_token?: string | null
          outcome_summary?: Json
          priority?: number
          proposal_id?: string | null
          recheck_trigger?: string | null
          request_reason?: string
          status?: string
          team_id?: string
          updated_at?: string
          work_kind?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_color_work_items_claimed_by_actor_id_fkey"
            columns: ["claimed_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_work_items_created_by_actor_id_fkey"
            columns: ["created_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_work_items_expected_current_color_version_id_fkey"
            columns: ["expected_current_color_version_id"]
            isOneToOne: false
            referencedRelation: "team_color_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_work_items_proposal_id_fkey"
            columns: ["proposal_id"]
            isOneToOne: false
            referencedRelation: "catalog_change_proposals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_work_items_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_color_work_items_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_color_work_items_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      team_competition_edition_participation_versions: {
        Row: {
          competition_edition_id: string
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          participating: boolean
          participation_role: string
          record_status: string
          superseded_at: string | null
          team_id: string
          verification_decision_id: string | null
        }
        Insert: {
          competition_edition_id: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          participating?: boolean
          participation_role?: string
          record_status: string
          superseded_at?: string | null
          team_id: string
          verification_decision_id?: string | null
        }
        Update: {
          competition_edition_id?: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          participating?: boolean
          participation_role?: string
          record_status?: string
          superseded_at?: string | null
          team_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_competition_edition_particip_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_competition_edition_participat_competition_edition_id_fkey"
            columns: ["competition_edition_id"]
            isOneToOne: false
            referencedRelation: "catalog_competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_competition_edition_participat_competition_edition_id_fkey"
            columns: ["competition_edition_id"]
            isOneToOne: false
            referencedRelation: "competition_edition_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_competition_edition_participation_ver_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_competition_edition_participation_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_competition_edition_participation_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_competition_edition_participation_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      team_identity_versions: {
        Row: {
          abbreviation: string | null
          active: boolean
          created_at: string
          display_name: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          founded_year: number | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          record_status: string
          short_name: string
          superseded_at: string | null
          team_id: string
          verification_decision_id: string | null
        }
        Insert: {
          abbreviation?: string | null
          active?: boolean
          created_at?: string
          display_name: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          founded_year?: number | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status: string
          short_name: string
          superseded_at?: string | null
          team_id: string
          verification_decision_id?: string | null
        }
        Update: {
          abbreviation?: string | null
          active?: boolean
          created_at?: string
          display_name?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          founded_year?: number | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status?: string
          short_name?: string
          superseded_at?: string | null
          team_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_identity_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_identity_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_identity_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_identity_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_identity_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      team_location_versions: {
        Row: {
          city: string | null
          country: string
          country_code: string | null
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          record_status: string
          region: string | null
          superseded_at: string | null
          team_id: string
          verification_decision_id: string | null
        }
        Insert: {
          city?: string | null
          country: string
          country_code?: string | null
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status: string
          region?: string | null
          superseded_at?: string | null
          team_id: string
          verification_decision_id?: string | null
        }
        Update: {
          city?: string | null
          country?: string
          country_code?: string | null
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status?: string
          region?: string | null
          superseded_at?: string | null
          team_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_location_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_location_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_location_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_location_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_location_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      team_logo_versions: {
        Row: {
          asset_id: string
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          logo_role: string
          record_status: string
          superseded_at: string | null
          team_id: string
          usage_status: string
          verification_decision_id: string | null
        }
        Insert: {
          asset_id: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          logo_role: string
          record_status: string
          superseded_at?: string | null
          team_id: string
          usage_status: string
          verification_decision_id?: string | null
        }
        Update: {
          asset_id?: string
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          logo_role?: string
          record_status?: string
          superseded_at?: string | null
          team_id?: string
          usage_status?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_logo_versions_asset_id_fkey"
            columns: ["asset_id"]
            isOneToOne: false
            referencedRelation: "catalog_media_assets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_logo_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_logo_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_logo_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_logo_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_logo_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      team_primary_league_versions: {
        Row: {
          conference_id: string | null
          created_at: string
          division_id: string | null
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          league_id: string
          record_status: string
          superseded_at: string | null
          team_id: string
          verification_decision_id: string | null
        }
        Insert: {
          conference_id?: string | null
          created_at?: string
          division_id?: string | null
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          league_id: string
          record_status: string
          superseded_at?: string | null
          team_id: string
          verification_decision_id?: string | null
        }
        Update: {
          conference_id?: string | null
          created_at?: string
          division_id?: string | null
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          league_id?: string
          record_status?: string
          superseded_at?: string | null
          team_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_primary_league_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_primary_league_versions_league_id_fkey"
            columns: ["league_id"]
            isOneToOne: false
            referencedRelation: "catalog_leagues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_primary_league_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_primary_league_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_primary_league_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_primary_league_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      team_venue_relationship_versions: {
        Row: {
          created_at: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          record_status: string
          relationship_type: string
          superseded_at: string | null
          team_id: string
          venue_id: string
          verification_decision_id: string | null
        }
        Insert: {
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status: string
          relationship_type: string
          superseded_at?: string | null
          team_id: string
          venue_id: string
          verification_decision_id?: string | null
        }
        Update: {
          created_at?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status?: string
          relationship_type?: string
          superseded_at?: string | null
          team_id?: string
          venue_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "team_venue_relationship_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_venue_relationship_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_venue_relationship_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_venue_relationship_versions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "team_venue_relationship_versions_venue_id_fkey"
            columns: ["venue_id"]
            isOneToOne: false
            referencedRelation: "catalog_venues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_venue_relationship_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      trusted_source_alias_versions: {
        Row: {
          alias: string
          alias_type: string
          created_at: string
          created_by_actor_id: string | null
          effective_from: string
          effective_to: string | null
          id: string
          is_current: boolean
          normalized_alias: string | null
          notes: string | null
          source_id: string
        }
        Insert: {
          alias: string
          alias_type: string
          created_at?: string
          created_by_actor_id?: string | null
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_alias?: string | null
          notes?: string | null
          source_id: string
        }
        Update: {
          alias?: string
          alias_type?: string
          created_at?: string
          created_by_actor_id?: string | null
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_current?: boolean
          normalized_alias?: string | null
          notes?: string | null
          source_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trusted_source_alias_versions_created_by_actor_id_fkey"
            columns: ["created_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trusted_source_alias_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_alias_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_alias_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_alias_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_alias_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      trusted_source_redirects: {
        Row: {
          canonical_source_id: string
          id: string
          reason: string
          redirected_at: string
          redirected_by_actor_id: string | null
          source_id: string
        }
        Insert: {
          canonical_source_id: string
          id?: string
          reason: string
          redirected_at?: string
          redirected_by_actor_id?: string | null
          source_id: string
        }
        Update: {
          canonical_source_id?: string
          id?: string
          reason?: string
          redirected_at?: string
          redirected_by_actor_id?: string | null
          source_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trusted_source_redirects_canonical_source_id_fkey"
            columns: ["canonical_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_canonical_source_id_fkey"
            columns: ["canonical_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_canonical_source_id_fkey"
            columns: ["canonical_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_canonical_source_id_fkey"
            columns: ["canonical_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_canonical_source_id_fkey"
            columns: ["canonical_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_redirected_by_actor_id_fkey"
            columns: ["redirected_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: true
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: true
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: true
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: true
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_redirects_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: true
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      trusted_source_url_scope_versions: {
        Row: {
          created_at: string
          created_by_actor_id: string | null
          effective_from: string
          effective_to: string | null
          hostname: string
          id: string
          include_subdomains: boolean
          is_current: boolean
          path_match: string
          path_prefix: string
          review_notes: string | null
          review_status: string
          scope_kind: string
          source_id: string
        }
        Insert: {
          created_at?: string
          created_by_actor_id?: string | null
          effective_from?: string
          effective_to?: string | null
          hostname: string
          id?: string
          include_subdomains?: boolean
          is_current?: boolean
          path_match?: string
          path_prefix?: string
          review_notes?: string | null
          review_status?: string
          scope_kind?: string
          source_id: string
        }
        Update: {
          created_at?: string
          created_by_actor_id?: string | null
          effective_from?: string
          effective_to?: string | null
          hostname?: string
          id?: string
          include_subdomains?: boolean
          is_current?: boolean
          path_match?: string
          path_prefix?: string
          review_notes?: string | null
          review_status?: string
          scope_kind?: string
          source_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "trusted_source_url_scope_versions_created_by_actor_id_fkey"
            columns: ["created_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trusted_source_url_scope_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_url_scope_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_url_scope_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_url_scope_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_source_url_scope_versions_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      trusted_sources: {
        Row: {
          base_url: string | null
          created_at: string
          display_name: string
          id: string
          import_batch_id: string | null
          independence_group_id: string | null
          metadata: Json
          notes: string | null
          reference_url: string | null
          review_status: string
          source_id: string
          superseded_at: string | null
          superseded_by_source_id: string | null
          updated_at: string
        }
        Insert: {
          base_url?: string | null
          created_at?: string
          display_name: string
          id?: string
          import_batch_id?: string | null
          independence_group_id?: string | null
          metadata?: Json
          notes?: string | null
          reference_url?: string | null
          review_status?: string
          source_id: string
          superseded_at?: string | null
          superseded_by_source_id?: string | null
          updated_at?: string
        }
        Update: {
          base_url?: string | null
          created_at?: string
          display_name?: string
          id?: string
          import_batch_id?: string | null
          independence_group_id?: string | null
          metadata?: Json
          notes?: string | null
          reference_url?: string | null
          review_status?: string
          source_id?: string
          superseded_at?: string | null
          superseded_by_source_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "trusted_sources_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trusted_sources_independence_group_id_fkey"
            columns: ["independence_group_id"]
            isOneToOne: false
            referencedRelation: "source_independence_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trusted_sources_superseded_by_source_id_fkey"
            columns: ["superseded_by_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_sources_superseded_by_source_id_fkey"
            columns: ["superseded_by_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_sources_superseded_by_source_id_fkey"
            columns: ["superseded_by_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_sources_superseded_by_source_id_fkey"
            columns: ["superseded_by_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "trusted_sources_superseded_by_source_id_fkey"
            columns: ["superseded_by_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      user_followed_teams: {
        Row: {
          created_at: string
          sort_order: number
          team_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          sort_order?: number
          team_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          sort_order?: number
          team_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_followed_teams_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      user_news_follow_requests: {
        Row: {
          created_at: string
          id: string
          input_kind: string
          raw_input: string
          request_id: string
          request_target_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          input_kind: string
          raw_input: string
          request_id?: string
          request_target_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          input_kind?: string
          raw_input?: string
          request_id?: string
          request_target_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_news_follow_requests_request_target_id_fkey"
            columns: ["request_target_id"]
            isOneToOne: false
            referencedRelation: "news_follow_request_targets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_follow_requests_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      user_news_follow_scopes: {
        Row: {
          created_at: string
          follow_id: string
          scope_type: string
          sport_id: string | null
          team_id: string | null
        }
        Insert: {
          created_at?: string
          follow_id: string
          scope_type: string
          sport_id?: string | null
          team_id?: string | null
        }
        Update: {
          created_at?: string
          follow_id?: string
          scope_type?: string
          sport_id?: string | null
          team_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_news_follow_scopes_follow_id_fkey"
            columns: ["follow_id"]
            isOneToOne: false
            referencedRelation: "user_news_identity_follows"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_follow_scopes_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_follow_scopes_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_follow_scopes_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "user_news_follow_scopes_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      user_news_identity_follows: {
        Row: {
          canonical_person_id_at_follow: string | null
          created_at: string
          followed_at: string
          id: string
          is_current: boolean
          muted_until: string | null
          organizational_contributor_id: string | null
          person_id: string | null
          person_merge_decision_ids_at_follow: string[]
          show_id: string | null
          target_type: string
          unfollowed_at: string | null
          user_id: string
        }
        Insert: {
          canonical_person_id_at_follow?: string | null
          created_at?: string
          followed_at?: string
          id?: string
          is_current?: boolean
          muted_until?: string | null
          organizational_contributor_id?: string | null
          person_id?: string | null
          person_merge_decision_ids_at_follow?: string[]
          show_id?: string | null
          target_type: string
          unfollowed_at?: string | null
          user_id: string
        }
        Update: {
          canonical_person_id_at_follow?: string | null
          created_at?: string
          followed_at?: string
          id?: string
          is_current?: boolean
          muted_until?: string | null
          organizational_contributor_id?: string | null
          person_id?: string | null
          person_merge_decision_ids_at_follow?: string[]
          show_id?: string | null
          target_type?: string
          unfollowed_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_news_identity_follows_canonical_person_id_at_follow_fkey"
            columns: ["canonical_person_id_at_follow"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_identity_follows_organizational_contributor_id_fkey"
            columns: ["organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_identity_follows_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_identity_follows_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_identity_follows_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      user_news_item_dismissals: {
        Row: {
          dismissed_at: string
          news_item_id: string
          user_id: string
        }
        Insert: {
          dismissed_at?: string
          news_item_id: string
          user_id: string
        }
        Update: {
          dismissed_at?: string
          news_item_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_news_item_dismissals_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_item_dismissals_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_item_dismissals_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_item_dismissals_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_news_item_dismissals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      user_settings: {
        Row: {
          navigation_side: string
          preferences: Json
          prototype_migration_version: number
          selected_team_id: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          navigation_side?: string
          preferences?: Json
          prototype_migration_version?: number
          selected_team_id?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          navigation_side?: string
          preferences?: Json
          prototype_migration_version?: number
          selected_team_id?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_settings_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["user_id"]
          },
        ]
      }
      venue_detail_versions: {
        Row: {
          city: string | null
          country: string | null
          country_code: string | null
          created_at: string
          display_name: string
          effective_from: string | null
          effective_from_precision: string
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          latitude: number | null
          longitude: number | null
          record_status: string
          region: string | null
          superseded_at: string | null
          venue_id: string
          verification_decision_id: string | null
        }
        Insert: {
          city?: string | null
          country?: string | null
          country_code?: string | null
          created_at?: string
          display_name: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          latitude?: number | null
          longitude?: number | null
          record_status: string
          region?: string | null
          superseded_at?: string | null
          venue_id: string
          verification_decision_id?: string | null
        }
        Update: {
          city?: string | null
          country?: string | null
          country_code?: string | null
          created_at?: string
          display_name?: string
          effective_from?: string | null
          effective_from_precision?: string
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          latitude?: number | null
          longitude?: number | null
          record_status?: string
          region?: string | null
          superseded_at?: string | null
          venue_id?: string
          verification_decision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "venue_detail_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venue_detail_versions_venue_id_fkey"
            columns: ["venue_id"]
            isOneToOne: false
            referencedRelation: "catalog_venues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venue_detail_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      venue_mapping_inventory_overrides: {
        Row: {
          id: string
          inventory_rule_id: string
          row_end: string | null
          row_start: string | null
          seat_values: Json
        }
        Insert: {
          id?: string
          inventory_rule_id: string
          row_end?: string | null
          row_start?: string | null
          seat_values: Json
        }
        Update: {
          id?: string
          inventory_rule_id?: string
          row_end?: string | null
          row_start?: string | null
          seat_values?: Json
        }
        Relationships: [
          {
            foreignKeyName: "venue_mapping_inventory_overrides_inventory_rule_id_fkey"
            columns: ["inventory_rule_id"]
            isOneToOne: false
            referencedRelation: "venue_mapping_inventory_rules"
            referencedColumns: ["id"]
          },
        ]
      }
      venue_mapping_inventory_rules: {
        Row: {
          id: string
          levels: string[]
          mapping_version_id: string
          row_values: Json
          rule_key: string
          seat_values: Json
          section_codes: string[]
        }
        Insert: {
          id?: string
          levels?: string[]
          mapping_version_id: string
          row_values?: Json
          rule_key: string
          seat_values?: Json
          section_codes?: string[]
        }
        Update: {
          id?: string
          levels?: string[]
          mapping_version_id?: string
          row_values?: Json
          rule_key?: string
          seat_values?: Json
          section_codes?: string[]
        }
        Relationships: [
          {
            foreignKeyName: "venue_mapping_inventory_rules_mapping_version_id_fkey"
            columns: ["mapping_version_id"]
            isOneToOne: false
            referencedRelation: "venue_mapping_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      venue_mapping_section_exceptions: {
        Row: {
          end_override: string | null
          exception_key: string
          id: string
          level_override: string | null
          row_end: string | null
          row_start: string | null
          seat_end: string | null
          seat_start: string | null
          section_id: string
          side_override: string | null
        }
        Insert: {
          end_override?: string | null
          exception_key: string
          id?: string
          level_override?: string | null
          row_end?: string | null
          row_start?: string | null
          seat_end?: string | null
          seat_start?: string | null
          section_id: string
          side_override?: string | null
        }
        Update: {
          end_override?: string | null
          exception_key?: string
          id?: string
          level_override?: string | null
          row_end?: string | null
          row_start?: string | null
          seat_end?: string | null
          seat_start?: string | null
          section_id?: string
          side_override?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "venue_mapping_section_exceptions_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "venue_mapping_sections"
            referencedColumns: ["id"]
          },
        ]
      }
      venue_mapping_sections: {
        Row: {
          id: string
          level: string
          mapping_version_id: string
          section_code: string
          side: string
          venue_end: string
        }
        Insert: {
          id?: string
          level: string
          mapping_version_id: string
          section_code: string
          side: string
          venue_end: string
        }
        Update: {
          id?: string
          level?: string
          mapping_version_id?: string
          section_code?: string
          side?: string
          venue_end?: string
        }
        Relationships: [
          {
            foreignKeyName: "venue_mapping_sections_mapping_version_id_fkey"
            columns: ["mapping_version_id"]
            isOneToOne: false
            referencedRelation: "venue_mapping_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      venue_mapping_sports: {
        Row: {
          mapping_version_id: string
          sport_id: string
        }
        Insert: {
          mapping_version_id: string
          sport_id: string
        }
        Update: {
          mapping_version_id?: string
          sport_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "venue_mapping_sports_mapping_version_id_fkey"
            columns: ["mapping_version_id"]
            isOneToOne: false
            referencedRelation: "venue_mapping_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venue_mapping_sports_sport_id_fkey"
            columns: ["sport_id"]
            isOneToOne: false
            referencedRelation: "catalog_sports"
            referencedColumns: ["id"]
          },
        ]
      }
      venue_mapping_team_profiles: {
        Row: {
          ends: string[]
          id: string
          levels: string[]
          mapping_version_id: string
          sides: string[]
          team_id: string
        }
        Insert: {
          ends: string[]
          id?: string
          levels: string[]
          mapping_version_id: string
          sides: string[]
          team_id: string
        }
        Update: {
          ends?: string[]
          id?: string
          levels?: string[]
          mapping_version_id?: string
          sides?: string[]
          team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "venue_mapping_team_profiles_mapping_version_id_fkey"
            columns: ["mapping_version_id"]
            isOneToOne: false
            referencedRelation: "venue_mapping_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venue_mapping_team_profiles_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "catalog_teams"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venue_mapping_team_profiles_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_catalog_read_model"
            referencedColumns: ["internal_id"]
          },
          {
            foreignKeyName: "venue_mapping_team_profiles_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "team_readiness"
            referencedColumns: ["internal_id"]
          },
        ]
      }
      venue_mapping_versions: {
        Row: {
          created_at: string
          effective_from: string | null
          effective_to: string | null
          id: string
          import_batch_id: string | null
          is_current: boolean
          record_status: string
          routing_convention_version: number
          seating_chart_image_url: string | null
          seating_chart_source_label: string | null
          seating_chart_source_url: string | null
          section_format: string
          superseded_at: string | null
          venue_id: string
          verification_decision_id: string | null
          version: number
        }
        Insert: {
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status: string
          routing_convention_version: number
          seating_chart_image_url?: string | null
          seating_chart_source_label?: string | null
          seating_chart_source_url?: string | null
          section_format: string
          superseded_at?: string | null
          venue_id: string
          verification_decision_id?: string | null
          version: number
        }
        Update: {
          created_at?: string
          effective_from?: string | null
          effective_to?: string | null
          id?: string
          import_batch_id?: string | null
          is_current?: boolean
          record_status?: string
          routing_convention_version?: number
          seating_chart_image_url?: string | null
          seating_chart_source_label?: string | null
          seating_chart_source_url?: string | null
          section_format?: string
          superseded_at?: string | null
          venue_id?: string
          verification_decision_id?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "venue_mapping_versions_import_batch_id_fkey"
            columns: ["import_batch_id"]
            isOneToOne: false
            referencedRelation: "catalog_import_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venue_mapping_versions_venue_id_fkey"
            columns: ["venue_id"]
            isOneToOne: false
            referencedRelation: "catalog_venues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venue_mapping_versions_verification_decision_id_fkey"
            columns: ["verification_decision_id"]
            isOneToOne: false
            referencedRelation: "catalog_verification_decisions"
            referencedColumns: ["id"]
          },
        ]
      }
      verification_policies: {
        Row: {
          active: boolean
          allowed_trust_tiers: number[]
          configuration: Json
          consensus_strategy: string | null
          created_at: string
          data_type: string
          id: string
          is_current: boolean
          maximum_verifier_rounds: number | null
          minimum_evidence_count: number
          policy_key: string
          require_independent_sources: boolean
          require_independent_verifier: boolean
          required_matching_verifier_results: number | null
          superseded_at: string | null
          version: number
        }
        Insert: {
          active?: boolean
          allowed_trust_tiers: number[]
          configuration?: Json
          consensus_strategy?: string | null
          created_at?: string
          data_type: string
          id?: string
          is_current?: boolean
          maximum_verifier_rounds?: number | null
          minimum_evidence_count: number
          policy_key: string
          require_independent_sources?: boolean
          require_independent_verifier?: boolean
          required_matching_verifier_results?: number | null
          superseded_at?: string | null
          version: number
        }
        Update: {
          active?: boolean
          allowed_trust_tiers?: number[]
          configuration?: Json
          consensus_strategy?: string | null
          created_at?: string
          data_type?: string
          id?: string
          is_current?: boolean
          maximum_verifier_rounds?: number | null
          minimum_evidence_count?: number
          policy_key?: string
          require_independent_sources?: boolean
          require_independent_verifier?: boolean
          required_matching_verifier_results?: number | null
          superseded_at?: string | null
          version?: number
        }
        Relationships: []
      }
    }
    Views: {
      competition_catalog_read_model: {
        Row: {
          active: boolean | null
          aliases: Json | null
          competition_id: string | null
          country_region: string | null
          display_name: string | null
          external_identifiers: Json | null
          internal_id: string | null
          kind_id: string | null
          kind_name: string | null
          legacy_league_id: string | null
          primary_languages: string[] | null
          record_status: string | null
          short_name: string | null
          sport_id: string | null
          sport_name: string | null
        }
        Relationships: []
      }
      competition_edition_catalog_read_model: {
        Row: {
          active: boolean | null
          competition_id: string | null
          display_name: string | null
          edition_id: string | null
          ends_on: string | null
          internal_id: string | null
          kind_id: string | null
          record_status: string | null
          season_label: string | null
          sport_id: string | null
          starts_on: string | null
        }
        Relationships: []
      }
      competition_filter_group_read_model: {
        Row: {
          active: boolean | null
          competition_id: string | null
          competition_name: string | null
          competition_sport_id: string | null
          description: string | null
          display_name: string | null
          filter_group_id: string | null
          group_sport_id: string | null
          internal_id: string | null
          sort_order: number | null
        }
        Relationships: []
      }
      news_awaiting_publication_read_model: {
        Row: {
          bylines: Json | null
          classifications: Json | null
          created_by_actor_id: string | null
          created_by_user_id: string | null
          creation_origin: string | null
          destination_url: string | null
          destination_url_kind: string | null
          headline: string | null
          id: string | null
          item_kind: string | null
          item_version_id: string | null
          manifestation_id: string | null
          manifestation_kind: string | null
          manifestation_public_id: string | null
          manifestation_url_id: string | null
          news_item_id: string | null
          preview_kind: string | null
          preview_url: string | null
          publication_state: string | null
          publication_time: string | null
          publisher_id: string | null
          publisher_name: string | null
          publisher_source_id: string | null
          representative_destination_version_id: string | null
          show_id: string | null
          show_name: string | null
          summary: string | null
          version_number: number | null
        }
        Relationships: [
          {
            foreignKeyName: "news_content_decisions_decided_by_actor_id_fkey"
            columns: ["created_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_podcast_episodes_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_content_review_read_model: {
        Row: {
          case_type: string | null
          context: Json | null
          created_at: string | null
          decision_history: Json | null
          id: string | null
          manifestation_id: string | null
          manifestation_public_id: string | null
          news_item_id: string | null
          news_item_public_id: string | null
          resolved_at: string | null
          review_case_id: string | null
          status: string | null
          unresolved_question: string | null
          updated_at: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_content_review_cases_case_type_fkey"
            columns: ["case_type"]
            isOneToOne: false
            referencedRelation: "news_content_review_case_types"
            referencedColumns: ["case_type"]
          },
          {
            foreignKeyName: "news_content_review_cases_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_content_review_cases_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_manifestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_content_review_cases_manifestation_id_fkey"
            columns: ["manifestation_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["manifestation_id"]
          },
          {
            foreignKeyName: "news_content_review_cases_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_content_review_cases_news_item_id_fkey"
            columns: ["news_item_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["id"]
          },
        ]
      }
      news_identity_review_read_model: {
        Row: {
          affiliations: Json | null
          automatic_resolution_result: string | null
          case_id: string | null
          case_kind: string | null
          context: Json | null
          created_at: string | null
          decision_history: Json | null
          id: string | null
          possible_matches: Json | null
          profile_url: string | null
          proposed_identity_type: string | null
          proposed_name: string | null
          public_evidence: Json | null
          publisher_id: string | null
          publisher_name: string | null
          publisher_source_id: string | null
          raw_byline: string | null
          resolution_stop_reason: string | null
          resolved_at: string | null
          status: string | null
          subject_contributor_profile_id: string | null
          subject_organizational_contributor_id: string | null
          subject_person_id: string | null
          subject_show_id: string | null
          unresolved_question: string | null
          updated_at: string | null
        }
        Relationships: [
          {
            foreignKeyName: "news_identity_resolution_case_subject_contributor_profile__fkey"
            columns: ["subject_contributor_profile_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_contributor_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_case_subject_organizational_contr_fkey"
            columns: ["subject_organizational_contributor_id"]
            isOneToOne: false
            referencedRelation: "news_organizational_contributors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_awaiting_publication_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_published_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_publisher_policy_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "news_ready_item_read_model"
            referencedColumns: ["publisher_source_id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_publisher_source_id_fkey"
            columns: ["publisher_source_id"]
            isOneToOne: false
            referencedRelation: "trusted_sources"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_subject_person_id_fkey"
            columns: ["subject_person_id"]
            isOneToOne: false
            referencedRelation: "catalog_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_identity_resolution_cases_subject_show_id_fkey"
            columns: ["subject_show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_published_item_read_model: {
        Row: {
          bylines: Json | null
          classifications: Json | null
          created_by_actor_id: string | null
          created_by_user_id: string | null
          creation_origin: string | null
          destination_url: string | null
          destination_url_kind: string | null
          headline: string | null
          id: string | null
          item_kind: string | null
          item_version_id: string | null
          manifestation_id: string | null
          manifestation_kind: string | null
          manifestation_public_id: string | null
          manifestation_url_id: string | null
          news_item_id: string | null
          preview_kind: string | null
          preview_url: string | null
          publication_state: string | null
          publication_time: string | null
          publisher_id: string | null
          publisher_name: string | null
          publisher_source_id: string | null
          representative_destination_version_id: string | null
          show_id: string | null
          show_name: string | null
          summary: string | null
          version_number: number | null
        }
        Relationships: [
          {
            foreignKeyName: "news_content_decisions_decided_by_actor_id_fkey"
            columns: ["created_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_podcast_episodes_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      news_publisher_policy_read_model: {
        Row: {
          display_name: string | null
          effective_from: string | null
          news_status: string | null
          notes: string | null
          policy_version_id: string | null
          publisher_id: string | null
          publisher_source_id: string | null
        }
        Relationships: []
      }
      news_ready_item_read_model: {
        Row: {
          bylines: Json | null
          classifications: Json | null
          created_by_actor_id: string | null
          created_by_user_id: string | null
          creation_origin: string | null
          destination_url: string | null
          destination_url_kind: string | null
          headline: string | null
          id: string | null
          item_kind: string | null
          item_version_id: string | null
          manifestation_id: string | null
          manifestation_kind: string | null
          manifestation_public_id: string | null
          manifestation_url_id: string | null
          news_item_id: string | null
          preview_kind: string | null
          preview_url: string | null
          publication_state: string | null
          publication_time: string | null
          publisher_id: string | null
          publisher_name: string | null
          publisher_source_id: string | null
          representative_destination_version_id: string | null
          show_id: string | null
          show_name: string | null
          summary: string | null
          version_number: number | null
        }
        Relationships: [
          {
            foreignKeyName: "news_content_decisions_decided_by_actor_id_fkey"
            columns: ["created_by_actor_id"]
            isOneToOne: false
            referencedRelation: "catalog_actors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "news_podcast_episodes_show_id_fkey"
            columns: ["show_id"]
            isOneToOne: false
            referencedRelation: "podcast_shows"
            referencedColumns: ["id"]
          },
        ]
      }
      team_catalog_read_model: {
        Row: {
          abbreviation: string | null
          active: boolean | null
          city: string | null
          colors_status: string | null
          conference_id: string | null
          country: string | null
          country_code: string | null
          display_name: string | null
          division_id: string | null
          external_identifiers: Json | null
          founded_year: number | null
          identity_status: string | null
          internal_id: string | null
          location_status: string | null
          primary_color: string | null
          primary_league_id: string | null
          primary_league_name: string | null
          primary_league_short_name: string | null
          primary_league_status: string | null
          quaternary_color: string | null
          quinary_color: string | null
          region: string | null
          secondary_color: string | null
          short_name: string | null
          sport_id: string | null
          sport_name: string | null
          team_id: string | null
          tertiary_color: string | null
        }
        Relationships: []
      }
      team_color_source_reliability_read_model: {
        Row: {
          assessed_sample_size: number | null
          conservative_match_rate: number | null
          contradictions: number | null
          display_name: string | null
          independence_group_id: string | null
          independently_corroborated_observations: number | null
          league_breadth: number | null
          matches: number | null
          most_recent_outcome_at: string | null
          not_assessable: number | null
          raw_match_rate: number | null
          source_id: string | null
          sport_breadth: number | null
          team_breadth: number | null
          unresolved: number | null
        }
        Relationships: []
      }
      team_readiness: {
        Row: {
          catalog_missing_requirements: string[] | null
          catalog_ready: boolean | null
          internal_id: string | null
          live_cheer_missing_requirements: string[] | null
          live_cheer_ready: boolean | null
          team_id: string | null
        }
        Relationships: []
      }
      trusted_source_duplicate_candidates_read_model: {
        Row: {
          left_display_name: string | null
          left_review_status: string | null
          left_scope_version_id: string | null
          left_source_id: string | null
          reason: string | null
          right_display_name: string | null
          right_review_status: string | null
          right_scope_version_id: string | null
          right_source_id: string | null
        }
        Relationships: []
      }
      trusted_source_review_read_model: {
        Row: {
          base_url: string | null
          current_aliases: Json | null
          current_applicabilities: Json | null
          current_trust_tiers: Json | null
          current_url_scopes: Json | null
          display_name: string | null
          independence_group_id: string | null
          independence_group_name: string | null
          metadata: Json | null
          notes: string | null
          reference_url: string | null
          review_status: string | null
          source_id: string | null
          superseded_by_source_id: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      acknowledge_agent_work_wake: {
        Args: { wake_uuid: string }
        Returns: undefined
      }
      activate_my_profile_photo: {
        Args: {
          focal_x_value: number
          focal_y_value: number
          photo_id_value: string
          zoom_value: number
        }
        Returns: undefined
      }
      activate_my_profile_visual: {
        Args: {
          focal_x_value: number
          focal_y_value: number
          image_id_value: string
          zoom_value: number
        }
        Returns: undefined
      }
      add_catalog_proposal_evidence: {
        Args: {
          evidence_summary_value?: string
          evidence_url_value: string
          observed_at_value?: string
          proposal_id_value: string
          source_registry_id: string
          supports_proposal_value?: boolean
        }
        Returns: string
      }
      add_catalog_proposal_evidence_governed: {
        Args: {
          evidence_summary_value: string
          evidence_url_value: string
          observed_at_value: string
          proposal_id_value: string
          source_registry_id: string
          structured_claim_value: Json
          supports_proposal_value: boolean
        }
        Returns: string
      }
      add_team_color_proposal_evidence: {
        Args: {
          evidence_summary_value: string
          evidence_url_value: string
          observed_at_value: string
          proposal_id_value: string
          source_registry_id: string
          structured_claim_value: Json
          supports_proposal_value: boolean
        }
        Returns: string
      }
      add_team_color_verifier_evidence: {
        Args: {
          evidence_summary_value: string
          evidence_url_value: string
          information_lineage_basis_value?: string
          information_lineage_key_value?: string
          lease_token_value: string
          observed_at_value: string
          source_registry_id: string
          structured_claim_value: Json
          verification_work_item_uuid: string
        }
        Returns: string
      }
      add_trusted_source_alias: {
        Args: {
          alias_type_value: string
          alias_value: string
          notes_value?: string
          source_registry_id: string
        }
        Returns: string
      }
      adjudicate_source_qualification_subject: {
        Args: {
          data_type_value: string
          subject_id_value: string
          subject_type_value: string
        }
        Returns: number
      }
      admin_add_news_manifestation_url: {
        Args: {
          is_public_destination_value: boolean
          manifestation_id_value: string
          notes_value?: string
          primary_evidence_id_value: string
          url_kind_value: string
          url_value: string
        }
        Returns: string
      }
      admin_assign_news_manifestation: {
        Args: {
          manifestation_id_value: string
          news_item_id_value: string
          notes_value?: string
          primary_evidence_id_value: string
        }
        Returns: string
      }
      admin_create_agent_job_runtime_policy: {
        Args: {
          activate_value?: boolean
          configuration_value?: Json
          exhaustion_status_value: string
          job_type_value: string
          lease_seconds_value: number
          maximum_attempts_value: number
          permanent_failure_categories_value: string[]
          permanent_failure_status_value: string
          policy_key_value: string
          retry_delay_seconds_value: number[]
          retryable_failure_categories_value: string[]
          version_value: number
        }
        Returns: string
      }
      admin_create_catalog_revalidation_policy: {
        Args: {
          activate_value?: boolean
          configuration_value?: Json
          data_type_value: string
          policy_key_value: string
          review_cadence_value: string
          version_value: number
        }
        Returns: string
      }
      admin_create_catalog_verification_round_policy: {
        Args: {
          allowed_trust_tiers_value?: number[]
          minimum_evidence_count_value?: number
          minimum_high_trust_evidence_count_value?: number
          minimum_independent_information_lineages_value?: number
          minimum_independent_ownership_groups_value?: number
          source_selection_policy_value?: Json
          verification_policy_uuid: string
          verification_round_value: number
        }
        Returns: string
      }
      admin_create_information_lineage_resolution_policy: {
        Args: {
          activate_value?: boolean
          automatically_permitted_actions_value: string[]
          configuration_value?: Json
          data_type_value: string
          policy_key_value: string
          version_value: number
        }
        Returns: string
      }
      admin_create_news_item: {
        Args: {
          episode_identifier_value: string
          headline_value: string
          item_kind_value: string
          notes_value?: string
          publication_state_value: string
          publication_time_evidence_id_value: string
          publication_time_value: string
          show_id_value: string
          source_publisher_id_value: string
          summary_value: string
        }
        Returns: string
      }
      admin_create_news_manifestation: {
        Args: {
          first_observed_at_value: string
          manifestation_kind_value: string
          notes_value?: string
          primary_evidence_id_value: string
          publisher_source_id_value: string
          source_reference_value: string
        }
        Returns: string
      }
      admin_create_news_publisher_contributor_profile: {
        Args: { case_id_value: string; notes_value?: string }
        Returns: string
      }
      admin_create_verification_policy: {
        Args: {
          activate_value?: boolean
          allowed_trust_tiers_value: number[]
          configuration_value?: Json
          data_type_value: string
          minimum_evidence_count_value: number
          policy_key_value: string
          require_independent_sources_value?: boolean
          require_independent_verifier_value?: boolean
        }
        Returns: string
      }
      admin_get_news_published_items_at: {
        Args: { at_time_value: string }
        Returns: {
          bylines: Json | null
          classifications: Json | null
          created_by_actor_id: string | null
          created_by_user_id: string | null
          creation_origin: string | null
          destination_url: string | null
          destination_url_kind: string | null
          headline: string | null
          id: string | null
          item_kind: string | null
          item_version_id: string | null
          manifestation_id: string | null
          manifestation_kind: string | null
          manifestation_public_id: string | null
          manifestation_url_id: string | null
          news_item_id: string | null
          preview_kind: string | null
          preview_url: string | null
          publication_state: string | null
          publication_time: string | null
          publisher_id: string | null
          publisher_name: string | null
          publisher_source_id: string | null
          representative_destination_version_id: string | null
          show_id: string | null
          show_name: string | null
          summary: string | null
          version_number: number | null
        }[]
        SetofOptions: {
          from: "*"
          to: "news_ready_item_read_model"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      admin_grant_catalog_capability: {
        Args: {
          actor_key_value: string
          capability_value: string
          league_public_id?: string
          sport_public_id?: string
          team_public_id?: string
          venue_public_id?: string
        }
        Returns: string
      }
      admin_lift_community_posting_restriction: {
        Args: { reason_value: string; restriction_public_id_value: string }
        Returns: Json
      }
      admin_moderate_community_report: {
        Args: {
          action_value: string
          reason_value: string
          report_public_id_value: string
        }
        Returns: Json
      }
      admin_open_news_attribution_review_case: {
        Args: {
          byline_mention_id_value: string
          context_value?: Json
          manifestation_id_value: string
          news_item_id_value: string
          notes_value?: string
          subject_identity_id_value: string
          subject_identity_type_value: string
          unresolved_question_value: string
        }
        Returns: string
      }
      admin_open_news_content_review_case: {
        Args: {
          case_type_value: string
          context_value?: Json
          manifestation_id_value: string
          news_item_id_value: string
          notes_value?: string
          unresolved_question_value: string
        }
        Returns: string
      }
      admin_open_news_identity_case: {
        Args: {
          case_kind_value: string
          context_value?: Json
          notes_value?: string
          profile_url_value: string
          proposed_identity_type_value: string
          proposed_name_value: string
          publisher_source_id_value: string
          raw_byline_value: string
          subject_contributor_profile_id_value: string
          subject_organizational_contributor_id_value: string
          subject_person_id_value: string
          subject_show_id_value: string
          unresolved_question_value: string
        }
        Returns: string
      }
      admin_record_news_byline: {
        Args: {
          manifestation_id_value: string
          notes_value?: string
          ordinal_value: number
          primary_evidence_id_value: string
          raw_attribution_value: string
          visible_profile_url_value: string
        }
        Returns: string
      }
      admin_record_news_classification: {
        Args: {
          classification_id_value: string
          news_item_id_value: string
          notes_value?: string
          primary_evidence_id_value: string
          target_id_value: string
          target_type_value: string
        }
        Returns: string
      }
      admin_record_news_content_evidence: {
        Args: {
          evidence_kind_value: string
          evidence_summary_value: string
          evidence_url_value: string
          notes_value?: string
          observed_at_value: string
          publisher_source_id_value: string
        }
        Returns: string
      }
      admin_record_news_deduplication: {
        Args: {
          manifestation_one_id_value: string
          manifestation_two_id_value: string
          notes_value?: string
          outcome_value: string
          primary_evidence_id_value: string
          rationale_value: string
          reconcile_manifestation_id_value?: string
          reconcile_news_item_id_value?: string
        }
        Returns: string
      }
      admin_record_news_identity_candidate: {
        Args: {
          candidate_kind_value: string
          case_id_value: string
          display_name_value: string
          identity_type_value: string
          notes_value?: string
          proposed_facts_value?: Json
          target_identity_id_value: string
        }
        Returns: string
      }
      admin_record_news_identity_evidence: {
        Args: {
          bridge_from_publisher_source_id_value: string
          bridge_to_publisher_source_id_value: string
          candidate_id_value: string
          case_id_value: string
          evidence_kind_value: string
          evidence_summary_value: string
          evidence_url_value: string
          is_conflicting_value: boolean
          notes_value?: string
          observed_at_value?: string
          observed_payload_value?: Json
          publisher_source_id_value: string
          visibility_value: string
        }
        Returns: string
      }
      admin_record_news_item_version: {
        Args: {
          headline_value: string
          news_item_id_value: string
          notes_value?: string
          publication_state_value: string
          publication_time_evidence_id_value: string
          publication_time_value: string
          source_publisher_id_value: string
          summary_value: string
        }
        Returns: string
      }
      admin_record_news_official_team_publication: {
        Args: {
          case_id_value: string
          effective_from_value: string
          effective_to_value: string
          notes_value?: string
          relationship_id_value?: string
          relationship_type_value: string
          team_id_value: string
        }
        Returns: string
      }
      admin_record_news_remote_preview: {
        Args: {
          alt_text_value: string
          manifestation_id_value: string
          notes_value?: string
          preview_kind_value: string
          primary_evidence_id_value: string
          publisher_policy_state_value: string
          remote_url_value: string
        }
        Returns: string
      }
      admin_record_podcast_show_contributor: {
        Args: {
          case_id_value: string
          contributor_role_value: string
          effective_from_value: string
          effective_to_value: string
          notes_value?: string
          person_id_value: string
          relationship_id_value?: string
        }
        Returns: string
      }
      admin_record_podcast_show_publisher: {
        Args: {
          case_id_value: string
          effective_from_value: string
          effective_to_value: string
          notes_value?: string
          publisher_source_id_value: string
          relationship_id_value?: string
          relationship_type_value: string
        }
        Returns: string
      }
      admin_register_catalog_domain_adapter: {
        Args: {
          active_value?: boolean
          build_verifier_context_function_value: unknown
          compare_result_function_value: unknown
          configuration_value?: Json
          data_type_value: string
          enqueue_revalidation_function_value?: unknown
          finalize_authoritative_function_value: unknown
          reconcile_wakes_function_value?: unknown
          recover_domain_function_value?: unknown
          specialist_job_type_value: string
          subject_type_value: string
          verification_capability_value: string
          verification_job_type_value: string
        }
        Returns: string
      }
      admin_register_source_qualification_adapter: {
        Args: {
          build_context_function_value: unknown
          compare_result_function_value: unknown
          data_type_value: string
          normalize_result_function_value: unknown
          record_contributions_function_value: unknown
          resolve_reference_function_value: unknown
        }
        Returns: string
      }
      admin_resolve_news_byline: {
        Args: {
          byline_mention_id_value: string
          identity_resolution_decision_id_value: string
          notes_value?: string
          resolution_basis_value: string
          target_identity_id_value: string
          target_identity_type_value: string
        }
        Returns: string
      }
      admin_resolve_news_follow_request: {
        Args: {
          follow_target_public_id_value: string
          follow_target_type_value: string
          outcome_value: string
          reason_value: string
          request_target_public_id_value: string
        }
        Returns: Json
      }
      admin_review_information_lineage: {
        Args: {
          canonical_lineage_key_value?: string
          data_type_value: string
          display_name_value: string
          lineage_key_value: string
          notes_value?: string
          origin_url_value: string
          provenance_value?: Json
          review_status_value: string
        }
        Returns: string
      }
      admin_review_news_content_case: {
        Args: {
          action_payload_value?: Json
          action_value: string
          notes_value?: string
          review_case_id_value: string
        }
        Returns: string
      }
      admin_review_news_identity_case: {
        Args: {
          action_payload_value?: Json
          action_value: string
          case_id_value: string
          notes_value?: string
          target_identity_id_value?: string
        }
        Returns: string
      }
      admin_set_news_demo_universe: {
        Args: { notes_value: string; targets_value: Json }
        Returns: string
      }
      admin_set_news_identity_followability: {
        Args: {
          followable_value: boolean
          rationale_value: string
          target_public_id_value: string
          target_type_value: string
        }
        Returns: string
      }
      admin_set_news_remote_preview_policy: {
        Args: {
          notes_value?: string
          preview_reference_id_value: string
          primary_evidence_id_value: string
          publisher_policy_state_value: string
        }
        Returns: string
      }
      admin_set_news_representative_destination: {
        Args: {
          manifestation_url_id_value: string
          news_item_id_value: string
          notes_value?: string
          primary_evidence_id_value: string
        }
        Returns: string
      }
      admin_set_source_trust_tier: {
        Args: {
          data_type_value: string
          notes_value?: string
          source_registry_id: string
          trust_tier_value: number
        }
        Returns: string
      }
      admin_upsert_catalog_actor: {
        Args: {
          active_value?: boolean
          actor_key_value: string
          actor_type_value: string
          auth_user_id_value: string
          display_name_value: string
        }
        Returns: string
      }
      admin_upsert_source_independence_group: {
        Args: {
          display_name_value: string
          group_id_value: string
          notes_value?: string
        }
        Returns: string
      }
      admin_upsert_trusted_source: {
        Args: {
          base_url_value?: string
          display_name_value: string
          independence_group_value?: string
          metadata_value?: Json
          notes_value?: string
          reference_url_value?: string
          review_status_value?: string
          source_id_value: string
        }
        Returns: string
      }
      applicable_source_applicability_version: {
        Args: {
          data_type_value: string
          source_uuid: string
          team_uuid: string
        }
        Returns: string
      }
      applicable_source_version_for_subject: {
        Args: {
          capability_scope_value: Json
          data_type_value: string
          source_uuid: string
        }
        Returns: string
      }
      applicable_team_color_sources: {
        Args: { team_uuid: string }
        Returns: Json
      }
      apply_information_lineage_resolution_result: {
        Args: {
          application_basis_value: string
          approved_lineage_key_value: string
          provenance_value?: Json
          resolution_result_uuid: string
        }
        Returns: string
      }
      assign_catalog_evidence_information_lineage: {
        Args: {
          basis_value: string
          evidence_uuid: string
          lineage_key_value: string
        }
        Returns: string
      }
      attach_resolved_source_qualification_lineage: {
        Args: { lineage_version_uuid: string; qualification_work_uuid: string }
        Returns: boolean
      }
      build_team_color_source_qualification_context: {
        Args: { subject_id_value: string; subject_type_value: string }
        Returns: Json
      }
      build_team_color_verifier_context: {
        Args: {
          specialist_result_kind_value: string
          specialist_result_uuid: string
          verification_round_value: number
        }
        Returns: Json
      }
      cancel_team_color_work: {
        Args: { reason_value: string; work_item_id_value: string }
        Returns: undefined
      }
      canonical_source_qualification_clean_cases: {
        Args: { enrollment_uuid: string }
        Returns: {
          outcome: string
          subject_id: string
          subject_type: string
        }[]
      }
      canonical_trusted_source_id: {
        Args: { source_uuid: string }
        Returns: string
      }
      catalog_source_evaluation_snapshot: {
        Args: { data_type_value: string; source_uuid: string }
        Returns: Json
      }
      catalog_verification_lineage_readiness: {
        Args: { verifier_result_uuid: string }
        Returns: Json
      }
      claim_next_catalog_verification_work: {
        Args: { data_type_value?: string }
        Returns: Json
      }
      claim_next_information_lineage_resolution_work: {
        Args: { data_type_value?: string }
        Returns: Json
      }
      claim_next_information_lineage_review_work: {
        Args: { data_type_value?: string }
        Returns: Json
      }
      claim_next_source_qualification_work: {
        Args: { data_type_value?: string }
        Returns: Json
      }
      claim_next_team_color_work: {
        Args: { lease_seconds_value?: number }
        Returns: Json
      }
      compare_team_color_source_qualification_result: {
        Args: { normalized_claim_value: Json; normalized_reference_value: Json }
        Returns: string
      }
      compare_team_color_verifier_result: {
        Args: { verifier_result_uuid: string }
        Returns: string
      }
      current_agent_backend_operating_policy: {
        Args: never
        Returns: {
          active: boolean
          configuration: Json
          created_at: string
          id: string
          is_current: boolean
          maximum_concurrent_operational_workers: number
          policy_key: string
          superseded_at: string | null
          version: number
          watchdog_interval: string
        }
        SetofOptions: {
          from: "*"
          to: "agent_backend_operating_policies"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      current_agent_job_runtime_policy: {
        Args: { job_type_value: string }
        Returns: {
          active: boolean
          configuration: Json
          created_at: string
          created_by_actor_id: string | null
          exhaustion_status: string
          id: string
          is_current: boolean
          job_type: string
          lease_seconds: number | null
          maximum_attempts: number | null
          permanent_failure_categories: string[]
          permanent_failure_status: string
          policy_key: string
          retry_delay_seconds: number[]
          retryable_failure_categories: string[]
          superseded_at: string | null
          version: number
        }
        SetofOptions: {
          from: "*"
          to: "agent_job_runtime_policies"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      current_agent_worker_pool_limit: {
        Args: { worker_pool_value: string }
        Returns: number
      }
      current_approved_information_lineage_version: {
        Args: { data_type_value: string; lineage_key_value: string }
        Returns: string
      }
      current_catalog_actor_id: { Args: never; Returns: string }
      current_information_lineage_root: {
        Args: { lineage_version_uuid: string }
        Returns: string
      }
      current_source_qualification_snapshot: {
        Args: {
          applicability_version_uuid: string
          data_type_value: string
          source_uuid: string
        }
        Returns: Json
      }
      current_source_trust_tier_assignment: {
        Args: { data_type_value: string; source_uuid: string }
        Returns: string
      }
      delete_my_community_comment: {
        Args: { comment_public_id_value: string }
        Returns: Json
      }
      dismiss_news_item: {
        Args: { news_item_public_id_value: string }
        Returns: undefined
      }
      dispatch_pending_team_color_bootstrap_revalidations: {
        Args: never
        Returns: number
      }
      edit_my_community_comment: {
        Args: { body_value: string; comment_public_id_value: string }
        Returns: Json
      }
      emit_agent_work_wake: {
        Args: {
          available_at_value: string
          eligibility_key_value: string
          event_kind_value: string
          queue_name_value: string
          work_item_id_value: string
        }
        Returns: string
      }
      enqueue_due_catalog_revalidations: {
        Args: { data_type_value: string }
        Returns: number
      }
      enqueue_information_lineage_resolution_work: {
        Args: {
          data_type_value: string
          evidence_kind_value: string
          evidence_uuid: string
          subject_id_value: string
          subject_type_value: string
        }
        Returns: string
      }
      enqueue_information_lineage_review_work: {
        Args: { resolution_result_uuid: string }
        Returns: string
      }
      enqueue_source_qualification_work: {
        Args: {
          assigned_source_location_value: string
          available_at_value?: string
          enrollment_uuid: string
          information_lineage_key_value: string
          priority_value?: number
          subject_id_value: string
          subject_type_value: string
        }
        Returns: string
      }
      enqueue_team_color_backlog: {
        Args: { batch_size_value?: number; priority_value?: number }
        Returns: number
      }
      enqueue_team_color_bootstrap_revalidation: {
        Args: { cohort_member_uuid: string }
        Returns: string
      }
      enqueue_team_color_revalidation: {
        Args: { revalidation_state_uuid: string }
        Returns: string
      }
      enqueue_team_color_work: {
        Args: {
          available_at_value?: string
          priority_value?: number
          reason_value?: string
          recheck_trigger_value?: string
          team_identifier: string
        }
        Returns: string
      }
      ensure_catalog_verification_work: {
        Args: { proposal_uuid: string }
        Returns: string
      }
      ensure_catalog_verification_work_for_result: {
        Args: {
          parent_verification_work_item_uuid?: string
          specialist_result_kind_value: string
          specialist_result_uuid: string
          verification_round_value?: number
        }
        Returns: string
      }
      ensure_source_qualification_enrollment: {
        Args: { data_type_value: string; source_uuid: string }
        Returns: string
      }
      evaluate_source_qualification: {
        Args: {
          enrollment_uuid: string
          force_canonical_merge_evaluation?: boolean
        }
        Returns: string
      }
      expire_catalog_verification_work_leases: { Args: never; Returns: number }
      expire_information_lineage_resolution_work_leases: {
        Args: never
        Returns: number
      }
      expire_information_lineage_review_work_leases: {
        Args: never
        Returns: number
      }
      expire_source_qualification_work_leases: {
        Args: { data_type_value?: string }
        Returns: number
      }
      expire_team_color_work_leases: { Args: never; Returns: number }
      finalize_catalog_authoritative_result: {
        Args: {
          authoritative_payload_value: Json
          data_type_value: string
          finalization_outcome_value: string
          specialist_result_kind_value: string
          specialist_result_uuid: string
          verification_decision_uuid: string
        }
        Returns: string
      }
      finalize_team_color_authoritative_result: {
        Args: {
          adjudication_uuid: string
          authoritative_payload_value: Json
          finalization_outcome_value: string
          specialist_result_kind_value: string
          specialist_result_uuid: string
        }
        Returns: string
      }
      finish_team_color_work: {
        Args: {
          category_value?: string
          lease_token_value: string
          outcome_value: string
          reason_value?: string
          retry_at_value?: string
          summary_value?: Json
          work_item_id_value: string
        }
        Returns: undefined
      }
      finish_team_color_work_pre_independent_verification: {
        Args: {
          category_value?: string
          lease_token_value: string
          outcome_value: string
          reason_value?: string
          retry_at_value?: string
          summary_value?: Json
          work_item_id_value: string
        }
        Returns: undefined
      }
      follow_news_identity: {
        Args: {
          sport_scope_ids_value?: string[]
          target_public_id_value: string
          target_type_value: string
          team_scope_ids_value?: string[]
        }
        Returns: string
      }
      get_active_community_posting_restrictions: { Args: never; Returns: Json }
      get_agent_work_wakes: {
        Args: { limit_value: number; queue_name_value?: string }
        Returns: {
          available_at: string
          created_at: string
          event_kind: string
          queue_name: string
          wake_id: string
          work_item_id: string
        }[]
      }
      get_community_discussion: {
        Args: { discussion_public_id_value: string }
        Returns: Json
      }
      get_community_moderation_queue: { Args: never; Returns: Json }
      get_member_profile_by_fanatical_name: {
        Args: { fanatical_name_value: string }
        Returns: Json
      }
      get_my_catalog_verification_work: {
        Args: { lease_token_value: string; verification_work_item_uuid: string }
        Returns: Json
      }
      get_my_community_moderation_notices: { Args: never; Returns: Json }
      get_my_community_notifications: { Args: never; Returns: Json }
      get_my_hidden_fans: { Args: never; Returns: Json }
      get_my_information_lineage_resolution_work: {
        Args: { lease_token_value: string; work_item_uuid: string }
        Returns: Json
      }
      get_my_information_lineage_review_work: {
        Args: { lease_token_value: string; work_item_uuid: string }
        Returns: Json
      }
      get_my_news_feed: {
        Args: {
          cursor_news_item_id_value?: string
          cursor_publication_time_value?: string
          filter_kind_value?: string
          filter_target_public_id_value?: string
          page_size_value?: number
        }
        Returns: {
          bylines: Json
          classifications: Json
          destination_url: string
          headline: string
          item_kind: string
          news_item_id: string
          preview_alt_text: string
          preview_kind: string
          preview_url: string
          publication_time: string
          publisher_id: string
          publisher_name: string
          server_time: string
          show_id: string
          show_name: string
          summary: string
        }[]
      }
      get_my_news_follow_requests: { Args: never; Returns: Json }
      get_my_news_following: {
        Args: never
        Returns: {
          display_name: string
          follow_ids: string[]
          muted_until: string
          needs_reselection: boolean
          sport_scope_ids: string[]
          target_id: string
          target_type: string
          team_scope_ids: string[]
        }[]
      }
      get_my_news_zero_follow_example: {
        Args: { team_public_id_value: string }
        Returns: {
          bylines: Json
          classifications: Json
          destination_url: string
          headline: string
          item_kind: string
          news_item_id: string
          preview_alt_text: string
          preview_kind: string
          preview_url: string
          publication_time: string
          publisher_id: string
          publisher_name: string
          server_time: string
          show_id: string
          show_name: string
          summary: string
        }[]
      }
      get_my_source_qualification_work: {
        Args: { lease_token_value: string; work_item_uuid: string }
        Returns: Json
      }
      get_my_team_color_work: {
        Args: { lease_token_value: string; work_item_id_value: string }
        Returns: Json
      }
      get_my_team_color_work_pre_publisher_governance: {
        Args: { lease_token_value: string; work_item_id_value: string }
        Returns: Json
      }
      get_news_demo_feed: {
        Args: {
          cursor_news_item_id_value?: string
          cursor_publication_time_value?: string
          filter_kind_value?: string
          filter_target_public_id_value?: string
          page_size_value?: number
          selected_targets_value: Json
        }
        Returns: {
          bylines: Json
          classifications: Json
          destination_url: string
          headline: string
          item_kind: string
          news_item_id: string
          preview_alt_text: string
          preview_kind: string
          preview_url: string
          publication_time: string
          publisher_id: string
          publisher_name: string
          server_time: string
          show_id: string
          show_name: string
          summary: string
        }[]
      }
      get_news_demo_universe: {
        Args: never
        Returns: {
          display_name: string
          ordinal: number
          target_id: string
          target_type: string
        }[]
      }
      get_news_discussion_teaser: {
        Args: {
          news_item_public_id_value: string
          origin_context_kind_value?: string
          origin_context_public_id_value?: string
        }
        Returns: Json
      }
      get_news_follow_request_queue: { Args: never; Returns: Json }
      get_news_identity_items: {
        Args: {
          cursor_news_item_id_value?: string
          cursor_publication_time_value?: string
          page_size_value?: number
          target_public_id_value: string
          target_type_value: string
        }
        Returns: {
          bylines: Json
          classifications: Json
          destination_url: string
          headline: string
          item_kind: string
          news_item_id: string
          preview_alt_text: string
          preview_kind: string
          preview_url: string
          publication_time: string
          publisher_id: string
          publisher_name: string
          server_time: string
          show_id: string
          show_name: string
          summary: string
        }[]
      }
      get_news_identity_profile: {
        Args: { target_public_id_value: string; target_type_value: string }
        Returns: {
          display_name: string
          target_id: string
          target_type: string
        }[]
      }
      get_news_manifestation_item_at: {
        Args: { at_time_value: string; manifestation_id_value: string }
        Returns: string
      }
      get_news_navigation: {
        Args: never
        Returns: {
          competition_kind_id: string
          display_name: string
          filter_type: string
          is_followed: boolean
          sport_id: string
          target_id: string
        }[]
      }
      get_news_person_pair_state_at: {
        Args: { at_time: string; person_one_id: string; person_two_id: string }
        Returns: {
          canonical_person_id: string
          closed_by_decision_id: string
          effective_from: string
          effective_to: string
          opened_by_decision_id: string
          state: string
        }[]
      }
      get_team_color_source_candidate_review_queue: {
        Args: never
        Returns: {
          base_url: string
          candidate_id: string
          created_at: string
          discovery_summary: string
          evidence_url: string
          observed_at: string
          reference_url: string
          review_status: string
          source_id: string
          source_name: string
          team_id: string
          team_name: string
          work_item_id: string
        }[]
      }
      get_team_news_discussions: {
        Args: { team_public_id_value: string }
        Returns: Json
      }
      get_team_record: { Args: { team_identifier: string }; Returns: Json }
      has_catalog_capability: {
        Args: {
          required_capability: string
          required_league_id?: string
          required_sport_id?: string
          required_team_id?: string
          required_venue_id?: string
        }
        Returns: boolean
      }
      has_catalog_verification_capability: {
        Args: { capability_scope_value: Json; data_type_value: string }
        Returns: boolean
      }
      has_staff_access: {
        Args: { required_permission?: string; required_roles?: string[] }
        Returns: boolean
      }
      has_team_color_capability: {
        Args: { requested_team_id: string; required_capability: string }
        Returns: boolean
      }
      hide_community_comment_author: {
        Args: { comment_public_id_value: string }
        Returns: Json
      }
      hide_community_user: {
        Args: { fanatical_name_value: string }
        Returns: Json
      }
      mark_my_community_moderation_notices_read: {
        Args: { notice_public_ids: string[] }
        Returns: number
      }
      mark_my_community_notifications_read: {
        Args: { notification_public_ids: string[] }
        Returns: number
      }
      mute_my_news_follow: {
        Args: { duration_value: string; follow_id_value: string }
        Returns: string
      }
      normalize_source_path: { Args: { path_value: string }; Returns: string }
      normalize_source_url: { Args: { url_value: string }; Returns: string }
      normalize_team_color_source_qualification_result: {
        Args: { result_payload_value: Json }
        Returns: Json
      }
      normalized_source_url_parts: {
        Args: { url_value: string }
        Returns: Json
      }
      post_existing_community_discussion_comment: {
        Args: { body_value: string; discussion_public_id_value: string }
        Returns: Json
      }
      post_news_discussion_comment: {
        Args: {
          body_value: string
          context_kind_value: string
          context_public_id_value: string
          news_item_public_id_value: string
        }
        Returns: Json
      }
      process_catalog_verification_result: {
        Args: { verifier_result_uuid: string }
        Returns: string
      }
      reconcile_canonical_source_qualification: {
        Args: {
          data_type_value: string
          force_canonical_merge_evaluation?: boolean
          source_uuid: string
        }
        Returns: string
      }
      reconcile_catalog_verification_comparison_wake_for_evidence: {
        Args: { evidence_kind_value: string; evidence_uuid: string }
        Returns: number
      }
      reconcile_catalog_verification_comparison_wakes: {
        Args: never
        Returns: number
      }
      reconcile_information_lineage_resolution_wakes: {
        Args: never
        Returns: number
      }
      reconcile_information_lineage_review_wakes: {
        Args: never
        Returns: number
      }
      reconcile_information_lineage_review_work_items: {
        Args: never
        Returns: number
      }
      reconcile_source_qualification_wakes: {
        Args: { data_type_value?: string }
        Returns: number
      }
      reconcile_team_color_wakes: { Args: never; Returns: number }
      record_news_outbound_open: {
        Args: {
          destination_url_value: string
          news_item_public_id_value: string
        }
        Returns: string
      }
      record_team_color_adjudication_source_contributions: {
        Args: { adjudication_uuid: string }
        Returns: number
      }
      record_team_color_bootstrap_completion: {
        Args: { proposal_uuid: string }
        Returns: boolean
      }
      record_team_color_revalidation_state: {
        Args: {
          decision_uuid: string
          fact_version_uuid: string
          outcome_value: string
          reason_value: string
          team_uuid: string
          trigger_value: string
        }
        Returns: undefined
      }
      recover_team_color_domain: { Args: never; Returns: Json }
      redirect_trusted_source: {
        Args: {
          canonical_source_registry_id: string
          reason_value: string
          source_registry_id: string
        }
        Returns: string
      }
      release_team_color_work: {
        Args: {
          category_value?: string
          lease_token_value: string
          reason_value?: string
          retry_at_value?: string
          work_item_id_value: string
        }
        Returns: undefined
      }
      release_team_color_work_pre_backend_retry_policy: {
        Args: {
          category_value?: string
          lease_token_value: string
          reason_value?: string
          retry_at_value?: string
          work_item_id_value: string
        }
        Returns: undefined
      }
      remove_my_profile_photo: {
        Args: { photo_id_value: string }
        Returns: Json
      }
      remove_my_profile_visual: {
        Args: { image_id_value: string }
        Returns: Json
      }
      renew_catalog_verification_work_lease: {
        Args: { lease_token_value: string; verification_work_item_uuid: string }
        Returns: string
      }
      renew_information_lineage_resolution_work_lease: {
        Args: { lease_token_value: string; work_item_uuid: string }
        Returns: string
      }
      renew_information_lineage_review_work_lease: {
        Args: { lease_token_value: string; work_item_uuid: string }
        Returns: string
      }
      renew_source_qualification_work_lease: {
        Args: { lease_token_value: string; work_item_uuid: string }
        Returns: string
      }
      renew_team_color_work_lease: {
        Args: {
          lease_seconds_value?: number
          lease_token_value: string
          work_item_id_value: string
        }
        Returns: string
      }
      replace_my_followed_teams: {
        Args: { team_ids: string[] }
        Returns: undefined
      }
      reply_to_community_comment: {
        Args: {
          body_value: string
          discussion_public_id_value: string
          parent_comment_public_id_value: string
        }
        Returns: Json
      }
      report_catalog_verification_failure: {
        Args: {
          category_value: string
          lease_token_value: string
          reason_value: string
          verification_work_item_uuid: string
        }
        Returns: string
      }
      report_community_comment: {
        Args: {
          comment_public_id_value: string
          explanation_value?: string
          reason_value: string
        }
        Returns: Json
      }
      report_information_lineage_resolution_failure: {
        Args: {
          failure_category_value: string
          failure_reason_value: string
          lease_token_value: string
          work_item_uuid: string
        }
        Returns: string
      }
      report_information_lineage_review_failure: {
        Args: {
          failure_category_value: string
          failure_reason_value: string
          lease_token_value: string
          work_item_uuid: string
        }
        Returns: string
      }
      report_source_qualification_work_failure: {
        Args: {
          failure_category_value: string
          failure_reason_value: string
          lease_token_value: string
          work_item_uuid: string
        }
        Returns: string
      }
      report_team_color_work_failure: {
        Args: {
          category_value: string
          lease_token_value: string
          reason_value: string
          summary_value?: Json
          work_item_id_value: string
        }
        Returns: string
      }
      requeue_team_color_work: {
        Args: {
          available_at_value?: string
          priority_value?: number
          reason_value?: string
          work_item_id_value: string
        }
        Returns: undefined
      }
      resolve_catalog_competition: {
        Args: { identifier_value: string; sport_identifier?: string }
        Returns: Json
      }
      resolve_catalog_competition_id: {
        Args: { identifier_value: string; sport_identifier?: string }
        Returns: string
      }
      resolve_catalog_team: {
        Args: { identifier_value: string }
        Returns: Json
      }
      resolve_catalog_team_id: {
        Args: { identifier_value: string }
        Returns: string
      }
      resolve_catalog_verification_source: {
        Args: {
          evidence_url_value: string
          lease_token_value: string
          verification_work_item_uuid: string
        }
        Returns: Json
      }
      resolve_news_canonical_person: {
        Args: { person_id_value: string }
        Returns: string
      }
      resolve_team_color_source: {
        Args: {
          evidence_url_value: string
          lease_token_value: string
          work_item_id_value: string
        }
        Returns: Json
      }
      resolve_team_color_source_qualification_reference: {
        Args: {
          subject_id_value: string
          subject_type_value: string
          tested_lineage_version_uuid: string
          tested_source_uuid: string
        }
        Returns: Json
      }
      resolve_trusted_source_url: {
        Args: { evidence_url_value: string }
        Returns: Json
      }
      review_catalog_proposal: {
        Args: {
          decision_value: string
          notes_value?: string
          proposal_id_value: string
        }
        Returns: string
      }
      review_catalog_proposal_pre_independent_verification: {
        Args: {
          decision_value: string
          notes_value?: string
          proposal_id_value: string
        }
        Returns: string
      }
      review_source_applicability: {
        Args: {
          applicability_kind_value: string
          data_type_value: string
          league_identifier?: string
          notes_value?: string
          review_status_value?: string
          source_registry_id: string
          sport_identifier?: string
          team_identifier?: string
        }
        Returns: string
      }
      review_trusted_source: {
        Args: {
          independence_group_value: string
          ownership_notes_value?: string
          review_status_value: string
          source_registry_id: string
        }
        Returns: string
      }
      review_trusted_source_url_scope: {
        Args: {
          hostname_value: string
          include_subdomains_value: boolean
          notes_value?: string
          path_match_value: string
          path_prefix_value: string
          review_status_value: string
          scope_kind_value: string
          source_registry_id: string
        }
        Returns: string
      }
      run_agent_backend_recovery: { Args: never; Returns: Json }
      save_my_profile: {
        Args: { identity_data: Json; profile_data: Json; sports_data: Json }
        Returns: undefined
      }
      schedule_additional_catalog_verification_round: {
        Args: { completed_verification_work_item_uuid: string }
        Returns: string
      }
      search_news_follow_targets: {
        Args: { query_value?: string; team_public_id_value?: string }
        Returns: {
          display_name: string
          target_id: string
          target_type: string
        }[]
      }
      set_my_fanatical_name: {
        Args: { fanatical_name_value: string }
        Returns: Json
      }
      set_my_news_follow_scopes: {
        Args: {
          follow_id_value: string
          sport_scope_ids_value?: string[]
          team_scope_ids_value?: string[]
        }
        Returns: undefined
      }
      set_my_profile_privacy: {
        Args: {
          personal_field_visibility_value?: Json
          visibility_value: string
        }
        Returns: Json
      }
      source_qualification_lineage_is_ready: {
        Args: { work_item_uuid: string }
        Returns: boolean
      }
      submit_catalog_proposal: {
        Args: {
          fact_type_value: string
          league_identifier?: string
          operation_value?: string
          payload_value: Json
          team_identifier?: string
          venue_identifier?: string
        }
        Returns: string
      }
      submit_catalog_verifier_result: {
        Args: {
          lease_token_value: string
          provenance_summary_value?: string
          result_kind_value: string
          result_payload_value: Json
          verification_work_item_uuid: string
        }
        Returns: string
      }
      submit_information_lineage_resolution_result: {
        Args: {
          lease_token_value: string
          proposed_lineage_key_value: string
          provenance_value?: Json
          resolution_action_value: string
          resolution_basis_value: string
          work_item_uuid: string
        }
        Returns: string
      }
      submit_information_lineage_review: {
        Args: {
          disposition_value: string
          existing_lineage_key_value?: string
          lease_token_value: string
          new_lineage_display_name_value?: string
          new_lineage_origin_url_value?: string
          provenance_value?: Json
          review_basis_value?: string
          terminal_exception_code_value?: string
          terminal_exception_reason_value?: string
          work_item_uuid: string
        }
        Returns: string
      }
      submit_news_follow_request: {
        Args: { input_kind_value: string; raw_input_value: string }
        Returns: Json
      }
      submit_source_qualification_result: {
        Args: {
          lease_token_value: string
          provenance_summary_value?: string
          result_kind_value: string
          result_payload_value: Json
          work_item_uuid: string
        }
        Returns: string
      }
      submit_team_color_proposal: {
        Args: {
          lease_token_value: string
          payload_value: Json
          reason_value: string
          work_item_id_value: string
        }
        Returns: string
      }
      submit_team_color_proposal_pre_independent_verification: {
        Args: {
          lease_token_value: string
          payload_value: Json
          reason_value: string
          work_item_id_value: string
        }
        Returns: string
      }
      submit_team_color_source_candidate: {
        Args: {
          base_url_value: string
          discovery_summary_value: string
          display_name_value: string
          evidence_url_value: string
          lease_token_value: string
          observed_at_value?: string
          reference_url_value: string
          source_registry_id: string
          work_item_id_value: string
        }
        Returns: string
      }
      submit_team_color_verifier_result: {
        Args: {
          lease_token_value: string
          provenance_summary_value?: string
          result_kind_value: string
          result_payload_value: Json
          verification_work_item_uuid: string
        }
        Returns: string
      }
      submit_team_registration_proposal: {
        Args: { payload_value: Json }
        Returns: string
      }
      team_color_authoritative_payload_from_palette: {
        Args: { palette_value: Json; proposal_payload_value: Json }
        Returns: Json
      }
      team_color_palette_from_payload: {
        Args: { payload_value: Json }
        Returns: Json
      }
      team_color_source_qualification_coverage: {
        Args: { enrollment_uuid: string }
        Returns: {
          applicable_team_count: number
          tested_applicable_team_count: number
        }[]
      }
      transition_catalog_verification_by_runtime_policy: {
        Args: {
          failure_category_value: string
          failure_reason_value: string
          verification_work_item_uuid: string
        }
        Returns: string
      }
      transition_information_lineage_resolution_by_runtime_policy: {
        Args: {
          failure_category_value: string
          failure_reason_value: string
          work_item_uuid: string
        }
        Returns: string
      }
      transition_information_lineage_review_by_runtime_policy: {
        Args: {
          failure_category_value: string
          failure_reason_value: string
          work_item_uuid: string
        }
        Returns: string
      }
      transition_source_qualification_work_by_runtime_policy: {
        Args: {
          failure_category_value: string
          failure_reason_value: string
          work_item_uuid: string
        }
        Returns: string
      }
      transition_team_color_work_by_runtime_policy: {
        Args: {
          failure_category_value: string
          failure_reason_value: string
          lease_actor_uuid?: string
          lease_token_value?: string
          require_live_lease?: boolean
          summary_value: Json
          work_item_uuid: string
        }
        Returns: string
      }
      trusted_source_url_matches: {
        Args: { evidence_url_value: string }
        Returns: {
          canonical_source_id: string
          matched_source_id: string
          specificity: number
          url_scope_version_id: string
        }[]
      }
      undo_news_item_dismissal: {
        Args: { news_item_public_id_value: string }
        Returns: undefined
      }
      unfollow_news_identity: {
        Args: { follow_id_value: string }
        Returns: undefined
      }
      unhide_community_intent: {
        Args: { hide_intent_public_id_value: string }
        Returns: Json
      }
      unhide_community_user: {
        Args: { fanatical_name_value: string }
        Returns: Json
      }
      unmute_my_news_follow: {
        Args: { follow_id_value: string }
        Returns: undefined
      }
      validate_team_color_claim: {
        Args: { claim_value: Json }
        Returns: boolean
      }
      withdraw_my_catalog_proposal: {
        Args: { proposal_id_value: string }
        Returns: undefined
      }
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

