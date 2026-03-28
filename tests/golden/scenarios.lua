local scenarios = {
    {
        id = "omni_force_create_partial_match",
        description = "force create is available only on partial/no-match states",
        expected = "create_path_offered_when_partial_or_none",
    },
    {
        id = "wiki_resolution_target_only",
        description = "display alias does not alter target resolution",
        expected = "resolution_uses_target_only_case_sensitive",
    },
    {
        id = "no_periodic_reconcile_baseline",
        description = "baseline does not schedule periodic reconcile",
        expected = "sync_requires_explicit_scan_or_watcher_events",
    },
    {
        id = "placeholder_registry_only",
        description = "no built-in placeholders are injected automatically",
        expected = "only_registered_placeholders_are_available",
    },
}

return scenarios
