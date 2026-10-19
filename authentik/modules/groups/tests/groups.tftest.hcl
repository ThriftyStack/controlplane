mock_provider "authentik" {}

variables {
  role_ids = {}
}

run "derives_five_levels" {
  command = plan

  variables {
    groups = {
      root = {
        name = "Root"
      }
      level_1 = {
        name    = "Level 1"
        parents = ["root"]
      }
      level_2 = {
        name    = "Level 2"
        parents = ["root", "level_1"]
      }
      level_3 = {
        name    = "Level 3"
        parents = ["level_2"]
      }
      level_4 = {
        name    = "Level 4"
        parents = ["level_2", "level_3"]
      }
    }
  }

  assert {
    condition = alltrue([
      toset(keys(authentik_group.level_0)) == toset(["root"]),
      toset(keys(authentik_group.level_1)) == toset(["level_1"]),
      toset(keys(authentik_group.level_2)) == toset(["level_2"]),
      toset(keys(authentik_group.level_3)) == toset(["level_3"]),
      toset(keys(authentik_group.level_4)) == toset(["level_4"]),
      toset(keys(output.ids)) == toset(["root", "level_1", "level_2", "level_3", "level_4"]),
    ])
    error_message = "Groups must be assigned to the level of their deepest parent."
  }
}

run "rejects_unknown_parent" {
  command = plan

  variables {
    groups = {
      orphan = {
        name    = "Orphan"
        parents = ["missing"]
      }
    }
  }

  expect_failures = [output.ids]
}

run "rejects_cycle" {
  command = plan

  variables {
    groups = {
      first = {
        name    = "First"
        parents = ["second"]
      }
      second = {
        name    = "Second"
        parents = ["first"]
      }
    }
  }

  expect_failures = [output.ids]
}

run "rejects_sixth_level" {
  command = plan

  variables {
    groups = {
      root = {
        name = "Root"
      }
      level_1 = {
        name    = "Level 1"
        parents = ["root"]
      }
      level_2 = {
        name    = "Level 2"
        parents = ["level_1"]
      }
      level_3 = {
        name    = "Level 3"
        parents = ["level_2"]
      }
      level_4 = {
        name    = "Level 4"
        parents = ["level_3"]
      }
      level_5 = {
        name    = "Level 5"
        parents = ["level_4"]
      }
    }
  }

  expect_failures = [output.ids]
}
