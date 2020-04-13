* Wiki documentation
* Switch from emergency access account and AADC service account exclusion groups to one exclusion and one exemptions group: Exemptions (in addition to exclusions), are cloud based groups, that typically are empty, but if a user is added to this group they are temporary exempted from the CA policy. So exemptions are temporary in nature as opposed to exclusions which are more static for service account scenarios.
* Multiple authentication options
* Add a ring based deployment model
* Add creation of access reviews for exemption and exclusion groups
* Should we add automation to mointor changes to the exemption and exclusion groups?
* Should we add automation for trusted locations?
* Should we add automation for app enforced restriction settings in EXO/SPO?
* Should we add automation for app protection policy creation?
* Should we add automation for enabling the combined MFA registration?
* Should we add automation to add group memebers to the exclusion group?
* Should we add automation for adding applications to policy in a targeted architecture? Add apps based on group membership, app in group

New polcies for the policy repository
* VM Sign-In in in WHfB cert trust org (Issue anyways)
* Compliance - Terms of Use
* Attack surface reduction - Unapproved apps: Block access
* Attack surface reduction - Unapproved apps: Block access For guests
* Attack surface reduction - All apps: Block access When connecting from an unapproved country
* Attack surface reduction - Azure management: Block access For non-admins
* Application protection, MCAS advanced control
* Application protection, MCAS block download control