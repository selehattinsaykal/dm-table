// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DM Table';

  @override
  String get navCampaigns => 'Campaigns';

  @override
  String get navCompendium => 'Library';

  @override
  String get navCharacters => 'Characters';

  @override
  String get navCompendiumShort => 'Library';

  @override
  String get navCharactersShort => 'Chars';

  @override
  String get navShopsShort => 'Shop';

  @override
  String get navCombat => 'Combat';

  @override
  String get navWorld => 'World';

  @override
  String get navShops => 'Shops';

  @override
  String get navSession => 'Session';

  @override
  String get navSettings => 'Settings';

  @override
  String get navLoot => 'Loot';

  @override
  String get navCodex => 'Codex';

  @override
  String get navMusic => 'Music';

  @override
  String get musicImport => 'Add files';

  @override
  String get musicNewPlaylist => 'New list';

  @override
  String get musicRenamePlaylist => 'Rename list';

  @override
  String get musicDeletePlaylistConfirm =>
      'Delete this list? Tracks are kept and become unfiled.';

  @override
  String get musicRenameTrack => 'Rename track';

  @override
  String get musicMoveTo => 'Move to list';

  @override
  String get musicUnfiled => 'Unfiled';

  @override
  String get musicEmpty =>
      'No tracks in this list. Add audio files with the button below; files are copied into the campaign folder and included in backups.';

  @override
  String get musicPlay => 'Play';

  @override
  String get musicPause => 'Pause';

  @override
  String get musicStop => 'Stop';

  @override
  String get musicNext => 'Next';

  @override
  String get musicPrevious => 'Previous';

  @override
  String get musicLoopOff => 'Repeat off';

  @override
  String get musicLoopAll => 'Repeat list';

  @override
  String get musicLoopOne => 'Repeat one track';

  @override
  String musicMissingFile(String title) {
    return '$title — file not found';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get settingsPartialTranslation =>
      'Some parts of the app are still Turkish only.';

  @override
  String get settingsAiTitle => 'AI (opt-in)';

  @override
  String get settingsAiProvider => 'Provider';

  @override
  String get settingsAiKey => 'API key';

  @override
  String get settingsAiModel => 'Model (optional)';

  @override
  String get settingsAiNote =>
      'Your key is stored only on this device. It never goes to players or over the LAN, and usage is billed to your own API account.';

  @override
  String get settingsAiSaved => 'Saved (on this device)';

  @override
  String get settingsAiActive => 'Key saved — AI tools active';

  @override
  String get settingsAiInactive => 'No key — AI tools disabled';

  @override
  String get codexAiSetting => 'Tavern / theme (optional)';

  @override
  String get codexAiGenerate => 'Generate';

  @override
  String get codexAiInsert => 'Add to Codex';

  @override
  String get codexAiCopy => 'Copy';

  @override
  String get codexAiCopied => 'Copied to clipboard';

  @override
  String get codexAiInserted => 'Added to Codex';

  @override
  String get codexAiNotConfigured =>
      'AI is not set up. Add an API key in Settings.';

  @override
  String get codexAiErrAuth => 'Invalid API key.';

  @override
  String get codexAiErrRate =>
      'Request limit reached, or this model is not available on your plan. The detail below says which.';

  @override
  String get codexAiErrNetwork => 'Network error. Check your connection.';

  @override
  String get codexAiErrRefused => 'The model declined this request.';

  @override
  String get codexAiErrEmpty => 'The model returned no text.';

  @override
  String get codexAiErrGeneric => 'Couldn’t generate. Try again.';

  @override
  String get navAiTools => 'AI Tools';

  @override
  String get aiToolQuest => 'Quest generator';

  @override
  String get aiOpenSettings => 'Open Settings';

  @override
  String get aiRegenerate => 'Start over';

  @override
  String get aiPickPage => 'Add to which page?';

  @override
  String get aiNoPages => 'Create a Codex page first.';

  @override
  String get aiQuestHeading => 'Quest';

  @override
  String get questPartySize => 'Party size';

  @override
  String get questPartyLevel => 'Party level';

  @override
  String get questDifficulty => 'Difficulty';

  @override
  String get questDiffVeryEasy => 'Very easy';

  @override
  String get questDiffEasy => 'Easy';

  @override
  String get questDiffMedium => 'Medium';

  @override
  String get questDiffHard => 'Hard';

  @override
  String get questDiffVeryHard => 'Very hard';

  @override
  String get questGiverNpc => 'Quest giver NPC';

  @override
  String get questGiverNone => 'None (free)';

  @override
  String get questGiverHint => 'Optional — ties the quest to this NPC.';

  @override
  String get questTargetLocation => 'Target location';

  @override
  String get questTargetNone => 'None (free)';

  @override
  String get questTargetHint => 'Optional — the quest leads here.';

  @override
  String get questSectionQuest => 'Quest text';

  @override
  String get questSectionReward => 'Reward';

  @override
  String get questSectionDm => 'DM-only notes';

  @override
  String get questDmOnly => 'Only you can see this — not shared with players';

  @override
  String get questCopyPlayer => 'Copy player version';

  @override
  String get questCopyAll => 'Copy all';

  @override
  String get questSendPlayers => 'Send to players';

  @override
  String get questSentPlayers => 'Sent to players';

  @override
  String get questNeedSession => 'Open the table from the Session tab first.';

  @override
  String get navQuests => 'Quests';

  @override
  String get questsNew => 'New quest';

  @override
  String get questsEmpty =>
      'No quests yet. Add one below or send from AI Tools.';

  @override
  String get questUntitled => '(untitled quest)';

  @override
  String get questAcceptedBy => 'Accepted';

  @override
  String get questRejectedBy => 'Declined';

  @override
  String get questPending => 'Pending';

  @override
  String get campaignDefaultName => 'Main Campaign';

  @override
  String get campaignExplainer =>
      'Each campaign is its own database file: characters, world, quests, codex and calendar all belong to that campaign. Only one campaign is open at a time.';

  @override
  String get campaignNew => 'New campaign';

  @override
  String get campaignNameLabel => 'Campaign name';

  @override
  String get campaignOpen => 'Open';

  @override
  String get campaignRename => 'Rename';

  @override
  String get campaignActive => 'Open campaign';

  @override
  String get campaignInactive => 'Closed';

  @override
  String campaignDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get campaignDeleteBody =>
      'This campaign\'s characters, world, quests, codex and all its images are permanently deleted. This cannot be undone.';

  @override
  String get campaignDeleted => 'Campaign deleted';

  @override
  String get campaignDeleteLater =>
      'The file is in use right now; the campaign will be deleted on next launch.';

  @override
  String get campaignSwitchTitle => 'Session is running';

  @override
  String get campaignSwitchBody =>
      'Switching campaigns closes the table, disconnects connected players and generates a new join address.';

  @override
  String campaignSwitchPlayers(String names) {
    return 'Connected players: $names';
  }

  @override
  String get campaignSwitchConfirm => 'Continue';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get calendarTabCalendar => 'Calendar';

  @override
  String get calendarTabChronicle => 'Chronicle';

  @override
  String get calendarTabReminders => 'Reminders';

  @override
  String get reminderNew => 'New reminder';

  @override
  String get reminderEmpty =>
      'No reminders yet. Note upcoming events here; you\'ll be reminded as days pass.';

  @override
  String get reminderTitle => 'Title';

  @override
  String get reminderBody => 'Note (optional)';

  @override
  String get reminderStart => 'Date';

  @override
  String get reminderRepeat => 'Repeat';

  @override
  String get reminderRepeatOnce => 'Once';

  @override
  String get reminderRepeatMonthly => 'Every month';

  @override
  String get reminderRepeatYearly => 'Every year';

  @override
  String reminderRepeatEveryNDays(int n) {
    return 'Every $n days';
  }

  @override
  String get reminderRepeatEveryNDaysShort => 'Every N days';

  @override
  String get reminderEveryNDaysLabel => 'Days between';

  @override
  String get reminderMonthlyHint =>
      'If a month is shorter than that day, the reminder moves to the month\'s last day instead of being skipped.';

  @override
  String reminderNext(String date) {
    return 'next: $date';
  }

  @override
  String get reminderNoNext => 'nothing scheduled';

  @override
  String get reminderClose => 'Close';

  @override
  String get reminderReopen => 'Reopen';

  @override
  String reminderFired(String titles) {
    return 'Reminder: $titles';
  }

  @override
  String get calendarTabSettings => 'Calendar structure';

  @override
  String get calendarDefaultMonths =>
      'Deepwinter,Thaw,Seedtime,Greening,Blossom,Midyear,Highsun,Harvest,Bounty,Leaffall,Mistfall,Longdark';

  @override
  String get calendarDefaultWeekdays =>
      'Anvilday,Hearthday,Waterday,Marketday,Roadday,Oathday,Restday';

  @override
  String get calendarDefaultSeasons => 'Spring,Summer,Autumn,Winter';

  @override
  String get calendarNoSeason => 'No season';

  @override
  String get calendarSetToday => 'Set today';

  @override
  String get calendarAdvanceDay => '+1 day';

  @override
  String get calendarAdvanceWeek => '+1 week';

  @override
  String get calendarBackDay => '-1 day';

  @override
  String get calendarGoToday => 'Back to today';

  @override
  String get calendarYear => 'Year';

  @override
  String get calendarMonth => 'Month';

  @override
  String get calendarDay => 'Day';

  @override
  String get calendarNameLabel => 'Calendar name';

  @override
  String get calendarEraLabel => 'Era label';

  @override
  String get calendarEraHint => 'Shown next to the year, e.g. \"Third Age\".';

  @override
  String get calendarYearSuffix => 'Year suffix (after epoch)';

  @override
  String get calendarYearSuffixHint =>
      'E.g. \"AD\" — 1492 AD. Used for year 0 and later.';

  @override
  String get calendarYearSuffixBefore => 'Year suffix (before epoch)';

  @override
  String get calendarYearSuffixBeforeHint =>
      'E.g. \"BC\" — 50 BC. Used for negative years.';

  @override
  String get calendarYearEraAfter => 'After';

  @override
  String get calendarYearEraBefore => 'Before';

  @override
  String get calendarMonths => 'Months';

  @override
  String get calendarAddMonth => 'Add month';

  @override
  String get calendarMonthDays => 'days';

  @override
  String get calendarWeekdays => 'Day names';

  @override
  String get calendarAddWeekday => 'Add day name';

  @override
  String get calendarWeekdaysHint =>
      'The length of a week is however many names you list here.';

  @override
  String get calendarSeasons => 'Seasons';

  @override
  String get calendarAddSeason => 'Add season';

  @override
  String calendarSeasonRange(String start, String end) {
    return '$start — $end';
  }

  @override
  String get calendarSeasonStart => 'Start';

  @override
  String get calendarSeasonEnd => 'End';

  @override
  String get calendarSeasonWrapHint =>
      'If the end comes before the start, the season wraps around the year (like winter).';

  @override
  String get calendarNoMonths =>
      'No months yet. Add them below or load the default calendar.';

  @override
  String get calendarSeedDefaults => 'Load default calendar';

  @override
  String get chronicleEmpty =>
      'No chronicle entries yet. Write your world\'s past here.';

  @override
  String get chronicleNew => 'New event';

  @override
  String get chronicleEventTitle => 'Event title';

  @override
  String get chronicleBody => 'What happened?';

  @override
  String get chronicleBodyHint =>
      'Write like in the Codex: **bold**, [[page]], /r 2d6, /monster(...)';

  @override
  String get chronicleCategory => 'Category';

  @override
  String get chronicleCategoryHint => 'Free text, e.g. war / treaty / disaster';

  @override
  String get chronicleSecret => 'Secret (only you know)';

  @override
  String get chronicleHasEnd => 'Ongoing event (has an end date)';

  @override
  String get chronicleEnd => 'End';

  @override
  String get chronicleKnownYearOnly => 'Only the year is known';

  @override
  String get chronicleEras => 'Eras';

  @override
  String get chronicleNewEra => 'New era';

  @override
  String get chronicleEraName => 'Era name';

  @override
  String get chronicleEraStart => 'Start year';

  @override
  String get chronicleEraEnd => 'End year (empty = ongoing)';

  @override
  String get chronicleOngoing => 'ongoing';

  @override
  String get chronicleNoEra => 'No era';

  @override
  String get chronicleSearch => 'Search the chronicle';

  @override
  String get chronicleDeleteConfirm => 'Delete this event permanently?';

  @override
  String chronicleEventsOnDay(String date) {
    return '$date';
  }

  @override
  String get chronicleNoEventsOnDay => 'Nothing recorded for this day.';

  @override
  String get chronicleAddHere => 'Add an event on this day';

  @override
  String get chronicleOnlySecret => 'Secret events only';

  @override
  String get restPartyTitle => 'Party rest';

  @override
  String get restPartyHint =>
      'Rests the selected characters at once; hit points in the combat tracker are updated too.';

  @override
  String get restEveryone => 'Everyone';

  @override
  String get restShortOpenHint =>
      'The rest is open to the players. Each of them spends as many hit dice as they like from their own panel; you are just watching.';

  @override
  String get restShortFinish => 'End the rest';

  @override
  String get restNeedSession => 'Open the table from the Session tab first.';

  @override
  String get restShort => 'Short rest';

  @override
  String get restLong => 'Long rest';

  @override
  String restHitDiceLeft(int left, int total) {
    return '$left / $total Hit Dice';
  }

  @override
  String restLongConfirm(int count) {
    return '$count characters will take a long rest: hit points are restored, spell slots return, half their Hit Dice come back and exhaustion drops by 1.';
  }

  @override
  String get restAdvanceDay => 'Advance the calendar by 1 day';

  @override
  String restLoggedLong(int count) {
    return 'Long rest ($count characters)';
  }

  @override
  String get restAnnounceLong => 'The party took a long rest.';

  @override
  String get aiToolEncounter => 'Encounter generator';

  @override
  String get encounterEnvironment => 'Environment / theme (optional)';

  @override
  String get encounterEnvironmentHint =>
      'E.g. swamp ruin, glacier pass, harbour warehouse.';

  @override
  String encounterBudgetHint(int xp) {
    return 'Target monster XP: $xp';
  }

  @override
  String get encounterSummary => 'Scene';

  @override
  String get encounterMonsters => 'Monsters';

  @override
  String get encounterTerrain => 'Terrain';

  @override
  String get encounterTactics => 'Tactics';

  @override
  String get encounterCreate => 'Turn into combat';

  @override
  String get encounterFallbackName => 'Encounter';

  @override
  String encounterCreated(String name) {
    return '$name created as a combat';
  }

  @override
  String encounterCreatedPartial(String name, String missing) {
    return '$name created — not found in the library: $missing';
  }

  @override
  String get encounterNoCandidates =>
      'No suitable monsters in the library for this level.';

  @override
  String get navChat => 'Chat';

  @override
  String get chatGeneral => 'General';

  @override
  String get chatWhisper => 'Whisper';

  @override
  String get chatPlaceholder => 'Type a message...';

  @override
  String get chatTo => 'To:';

  @override
  String get chatDm => 'DM';

  @override
  String get chatEmpty => 'No messages yet. Say something to the table.';

  @override
  String get chatNeedSession => 'Open the table from the Session tab first.';

  @override
  String get presenceTitle => 'Players';

  @override
  String get presenceDragHint => 'Long-press and drag to move';

  @override
  String get presenceNoPlayers => 'No players connected yet.';

  @override
  String get presenceActive => 'Active';

  @override
  String get presenceAway => 'Away';

  @override
  String get presenceOffline => 'Offline';

  @override
  String lastSeenSeconds(int n) {
    return 'last seen ${n}s ago';
  }

  @override
  String lastSeenMinutes(int n) {
    return 'last seen ${n}m ago';
  }

  @override
  String lastSeenHours(int n) {
    return 'last seen ${n}h ago';
  }

  @override
  String get questNoTargets => 'No players selected';

  @override
  String get questHide => 'Stop showing';

  @override
  String get questComplete => 'Complete';

  @override
  String get questReopen => 'Reopen';

  @override
  String get questSharePick => 'Show to which players?';

  @override
  String get questShow => 'Show';

  @override
  String get questShared => 'Shown to players';

  @override
  String get questNoCharacters => 'Create a character first.';

  @override
  String get questDelete => 'Delete quest';

  @override
  String get questDeleteConfirm => 'Delete this quest permanently?';

  @override
  String get questEditTitle => 'Quest';

  @override
  String get questTitleLabel => 'Title';

  @override
  String get questTextLabel => 'Quest text (for players)';

  @override
  String get questTextHelper => 'Text shown to players.';

  @override
  String get questRewardLabel => 'Reward';

  @override
  String get questDmLabel => 'DM notes (only you)';

  @override
  String get questDmHelper => 'Never sent to players.';

  @override
  String get questSendToQuests => 'Send to Quests';

  @override
  String get questSavedToQuests => 'Added to Quests';

  @override
  String get aiQuestRewardAuto =>
      'When you send this to Quests, the money and items below become the quest reward and open as a shared loot pool once the quest is completed.';

  @override
  String get questRealReward => 'Actual reward (items + money)';

  @override
  String get questRealRewardHint =>
      'When you complete the quest this opens as a shared loot pool for the players who accepted it. Whoever takes an item first gets it; the quest closes once the pool is empty.';

  @override
  String get questRewardPending => 'Reward being claimed';

  @override
  String questRewardItemCount(int count) {
    return '$count items';
  }

  @override
  String get questShareSection => 'Show to players';

  @override
  String get questModeIndividual => 'Individual accept';

  @override
  String get questModeVote => 'Party vote';

  @override
  String get questModeIndividualHint =>
      'Each player you pick accepts or declines the quest on their own.';

  @override
  String get questModeVoteHint =>
      'The players you pick vote. If 50% or more accept, everyone gets the quest; below that nobody does.';

  @override
  String get questStartVote => 'Start vote';

  @override
  String get questVoteStarted => 'Vote started';

  @override
  String get questVoteOngoing => 'Vote in progress';

  @override
  String get questVotePassed => 'Vote passed — party took it';

  @override
  String get questVoteFailed => 'Vote failed — nobody took it';

  @override
  String get compendiumMonsters => 'Monsters';

  @override
  String get compendiumSpells => 'Spells';

  @override
  String get compendiumItems => 'Items';

  @override
  String get compendiumMagicItems => 'Magic Items';

  @override
  String get compendiumFeats => 'Feats';

  @override
  String get compendiumSpecies => 'Species';

  @override
  String get compendiumBackgrounds => 'Backgrounds';

  @override
  String get searchHint => 'Search...';

  @override
  String get filters => 'Filters';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get noResults => 'No results';

  @override
  String get filterSchool => 'School';

  @override
  String get filterRarity => 'Rarity';

  @override
  String get importTitle => 'Preparing content';

  @override
  String get importSubtitle =>
      'The rules library is being set up for the first time; this happens once.';

  @override
  String importStepWriting(String table) {
    return 'Writing to database: $table';
  }

  @override
  String get importFailed => 'Content setup failed';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get close => 'Close';

  @override
  String get ok => 'OK';

  @override
  String get create => 'Create';

  @override
  String get remove => 'Remove';

  @override
  String get licenseTitle => 'Content licenses';

  @override
  String get licenseBody =>
      'The rules content in this app comes from the System Reference Document 5.2 (CC-BY 4.0) and openly licensed sets distributed via Open5e. Content you import from your personal library is stored only on this device.';

  @override
  String get sheetTitleFallback => 'Character';

  @override
  String get sheetRollDice => 'Roll dice';

  @override
  String get sheetLevelUp => 'Level up';

  @override
  String get sheetClassCounters => 'Class counters';

  @override
  String get sheetFeatures => 'Features';

  @override
  String get sheetAddFeature => 'Add feature';

  @override
  String get sheetEditFeature => 'Edit feature';

  @override
  String get sheetFeatureName => 'Name';

  @override
  String get sheetFeatureDesc => 'Description';

  @override
  String get sheetFeatureUses => 'Use limit';

  @override
  String get sheetFeatureUsesHint =>
      'Leave empty for unlimited, e.g. \"1\" for once per rest.';

  @override
  String get sheetFeatureCustom => 'Custom';

  @override
  String get sheetDeleteFeatureConfirm => 'Delete this feature?';

  @override
  String get sheetDamage => 'Damage';

  @override
  String get sheetHeal => 'Heal';

  @override
  String get sheetGrantTempHp => 'Grant temp HP';

  @override
  String get sheetDeathSaves => 'Death saving throws';

  @override
  String get sheetSuccess => 'Success';

  @override
  String get sheetFailure => 'Failure';

  @override
  String get sheetInitiative => 'Initiative';

  @override
  String get sheetSpeed => 'Speed';

  @override
  String get sheetProficiency => 'Proficiency';

  @override
  String get sheetPassivePerception => 'Passive Perception';

  @override
  String get sheetCarry => 'Carry';

  @override
  String get sheetSavingThrows => 'Saving throws';

  @override
  String get sheetSkills => 'Skills';

  @override
  String get sheetSpellSlots => 'Spell slots';

  @override
  String get sheetStatus => 'Status';

  @override
  String get sheetInspiration => 'Inspiration';

  @override
  String get sheetExhaustion => 'Exhaustion';

  @override
  String get sheetExperience => 'Experience (XP)';

  @override
  String sheetXpToNext(int nextLevel, int xpNeeded) {
    return '$xpNeeded XP to level $nextLevel';
  }

  @override
  String sheetXpMaxLevel(int level) {
    return 'Max level (Lv $level)';
  }

  @override
  String get sheetInventory => 'Inventory';

  @override
  String get sheetBagEmpty => 'Bag is empty.';

  @override
  String get sheetAddItem => 'Add item';

  @override
  String get sheetEquip => 'Equip';

  @override
  String get sheetUnequip => 'Unequip';

  @override
  String get sheetItemTab => 'Item';

  @override
  String get sheetMagicTab => 'Magic';

  @override
  String get sheetCustomTab => 'Custom';

  @override
  String get sheetItemName => 'Item name';

  @override
  String get sheetPurse => 'Purse';

  @override
  String get sheetRest => 'Rest';

  @override
  String get sheetShortRest => 'Short rest (hit die)';

  @override
  String get sheetLongRest => 'Long rest (full recharge)';

  @override
  String get sheetLongRestDone =>
      'Long rest taken: HP, slots, hit dice recharged.';

  @override
  String get sheetNoHitDice => 'No hit dice left to spend.';

  @override
  String get sheetPortrait => 'Portrait';

  @override
  String get sheetPortraitHint => 'Players see this in the Character tab.';

  @override
  String get sheetUploadPhoto => 'Upload photo';

  @override
  String get sheetChange => 'Change';

  @override
  String get sheetRemove => 'Remove';

  @override
  String get sheetSpells => 'Spells';

  @override
  String get sheetAddSpell => 'Add spell';

  @override
  String get sheetNoSpellsAdded => 'No spells added yet.';

  @override
  String get sheetAlways => 'always';

  @override
  String get sheetPrepared => 'Prepared';

  @override
  String get sheetPrepare => 'Prepare';

  @override
  String get sheetSearchSpell => 'Search spells';

  @override
  String get sheetOnlyClassSpells => 'Only class-appropriate';

  @override
  String get sheetStory => 'Story';

  @override
  String get sheetBackstory => 'Backstory';

  @override
  String get sheetAppearance => 'Appearance';

  @override
  String get sheetPersonality => 'Personality';

  @override
  String get sheetIdeal => 'Ideal';

  @override
  String get sheetBond => 'Bond';

  @override
  String get sheetFlaw => 'Flaw';

  @override
  String get combatNewEncounter => 'New encounter';

  @override
  String get combatPreparing => 'Preparing';

  @override
  String get combatEncounterName => 'Encounter';

  @override
  String get combatNameLabel => 'Name';

  @override
  String get combatCreate => 'Create';

  @override
  String get combatEmpty => 'No encounters';

  @override
  String get combatEmptyHint =>
      'Set up an encounter and add monsters and players.';

  @override
  String get combatAddMonster => 'Add monster';

  @override
  String get combatAddParty => 'Add players';

  @override
  String get combatAddHint =>
      'Use the buttons above to add monsters and players.';

  @override
  String get combatNeedCharacter => 'Create a character first.';

  @override
  String get combatEditInitiative => 'Set initiatives, then start';

  @override
  String get combatEnd => 'End';

  @override
  String get combatNext => 'Next';

  @override
  String get combatStart => 'Start';

  @override
  String get combatConcentration => 'Concentration';

  @override
  String get combatStatBlock => 'Stat block';

  @override
  String get combatEditConditions => 'Add/remove conditions';

  @override
  String get combatStartConcentration => 'Start concentration';

  @override
  String get combatEndConcentration => 'End concentration';

  @override
  String get combatMarkDefeated => 'Mark defeated';

  @override
  String get combatRevive => 'Revive';

  @override
  String get combatRemove => 'Remove';

  @override
  String get combatDamage => 'Damage';

  @override
  String get combatHeal => 'Heal';

  @override
  String get combatSearchMonster => 'Search monsters...';

  @override
  String get combatCount => 'Count';

  @override
  String get combatRollHp => 'Roll HP';

  @override
  String combatRoundN(int n) {
    return 'Round $n';
  }

  @override
  String combatInitiativeTitle(String name) {
    return '$name — initiative';
  }

  @override
  String combatConditionsTitle(String name) {
    return '$name — conditions';
  }

  @override
  String combatConditionsExpired(String name, String conditions) {
    return '$name: $conditions ended';
  }

  @override
  String get combatDurationRounds => 'Duration (rounds)';

  @override
  String get combatDurationUnlimited => 'Unlimited';

  @override
  String get combatAttackRoll => 'Attack';

  @override
  String get combatToHit => 'To hit';

  @override
  String get combatCritical => 'Critical';

  @override
  String get combatCriticalHit => 'Critical!';

  @override
  String get combatAdvantage => 'Advantage';

  @override
  String get combatDisadvantage => 'Disadvantage';

  @override
  String get combatNormalRoll => 'Normal';

  @override
  String get combatDifficulty => 'Difficulty';

  @override
  String get combatDiffTrivial => 'Trivial';

  @override
  String get combatDiffLow => 'Low';

  @override
  String get combatDiffModerate => 'Moderate';

  @override
  String get combatDiffHigh => 'High';

  @override
  String get combatDiffDeadly => 'Deadly';

  @override
  String get combatLegendaryActions => 'Legendary actions';

  @override
  String get combatLegendaryShort => 'Legendary';

  @override
  String get combatLegendaryResistShort => 'Resistance';

  @override
  String get combatLegendaryPerRound => 'Uses per round';

  @override
  String get combatLegendaryResetHint =>
      'Tap to spend, long-press to reset. Legendary actions refresh automatically at the start of the monster\'s turn; resistance is per day.';

  @override
  String get combatLegendaryNone => 'This monster has no legendary actions.';

  @override
  String combatLegendaryCost(Object n) {
    return '$n uses';
  }

  @override
  String combatLegendaryTooltip(Object max, Object remaining) {
    return '$remaining/$max left';
  }

  @override
  String get combatConditionLongPressHint =>
      'Tap: duration · Long-press: rules text';

  @override
  String get compendiumConditions => 'Conditions';

  @override
  String get compendiumConditionsEmpty => 'Conditions haven\'t been imported.';

  @override
  String combatBudgetSummary(int xp, int low, int moderate, int high) {
    return '$xp XP · budget L$low / M$moderate / H$high';
  }

  @override
  String combatUncounted(int count) {
    return '$count without XP not counted.';
  }

  @override
  String get combatAwardXp => 'Award XP';

  @override
  String get combatAwardXpNone => 'No monster XP or players to award.';

  @override
  String combatAwardXpConfirm(int total, int players, int each) {
    return 'Give $total XP to $players players ($each each)?';
  }

  @override
  String combatAwardXpDone(int each) {
    return 'XP awarded ($each each).';
  }

  @override
  String logXpAwarded(int total, int players, int each) {
    return 'Encounter XP: $total → $players players ($each each)';
  }

  @override
  String get worldNpcs => 'NPCs';

  @override
  String get worldNewLocation => 'New location';

  @override
  String get worldShowToPlayers => 'Show to players';

  @override
  String get worldAddChild => 'Add sub-location';

  @override
  String get worldRename => 'Rename';

  @override
  String get worldDeleteConfirmBody =>
      'This place and all its sub-locations, pins and maps will be permanently deleted.';

  @override
  String get worldEmpty => 'The world is empty';

  @override
  String get worldEmptyHint =>
      'Add a continent or region and upload its map. You can enter sub-locations from the pins you place on the map.';

  @override
  String get worldNameLabel => 'Name';

  @override
  String get worldParentLocation => 'Parent location';

  @override
  String get worldBack => 'Back';

  @override
  String get worldAddPin => 'Add pin';

  @override
  String get worldStopAddingPin => 'Stop adding pins';

  @override
  String get worldUploadMap => 'Upload map';

  @override
  String get worldChangeMap => 'Change map';

  @override
  String get worldRemoveMap => 'Remove map';

  @override
  String get worldDeleteLocation => 'Delete this place';

  @override
  String get worldTapToPlacePin => 'Tap the map to place a pin.';

  @override
  String get worldPinDragHint => 'Drag pins to move them. Tap to edit.';

  @override
  String get worldNoMap => 'No map';

  @override
  String get worldNoMapHint =>
      'After uploading a map you can place pins on it and enter sub-locations from them.';

  @override
  String get worldMapNotFound => 'Map file not found.';

  @override
  String get travelTitle => 'Travel';

  @override
  String get travelScaleTitle => 'Map scale';

  @override
  String get travelScaleHint =>
      'Enter how many miles across the map is in the real world. Distances between pins are derived from this.';

  @override
  String get travelWidthMiles => 'Width (miles)';

  @override
  String get travelHeightMiles => 'Height (miles)';

  @override
  String get travelHeightAuto =>
      'Left empty, it is derived from the map\'s aspect ratio.';

  @override
  String get travelScaleMissing =>
      'This map has no scale yet. Enter its width in miles to compute distances.';

  @override
  String get travelScaleSet => 'Set scale';

  @override
  String get travelScaleClear => 'Clear scale';

  @override
  String get travelNoPins =>
      'This map has no pins. A route needs at least two pins.';

  @override
  String get travelRoute => 'Route';

  @override
  String get travelAddStop => 'Add stop';

  @override
  String get travelPickTwoStops => 'Pick at least two stops.';

  @override
  String get travelSpeed => 'Speed';

  @override
  String get travelGroupPaces => 'Travel paces';

  @override
  String get travelGroupMounts => 'Mounts';

  @override
  String get travelGroupVehicles => 'Waterborne';

  @override
  String get travelCustomSpeed => 'Custom speed';

  @override
  String get travelMilesPerHour => 'Miles/hour';

  @override
  String get travelHoursPerDay => 'Hours travelled per day';

  @override
  String get travelExtraMiles => 'Extra distance (miles)';

  @override
  String get travelExtraMilesHint =>
      'Distance with no equivalent on this map (e.g. crossing to another map).';

  @override
  String travelTotalMiles(Object miles) {
    return '$miles miles total';
  }

  @override
  String travelDuration(Object days, Object hours) {
    return '$days days $hours hours';
  }

  @override
  String travelDurationDaysOnly(Object days) {
    return '$days days';
  }

  @override
  String travelAdvancesDays(Object days) {
    return 'Calendar advances $days days';
  }

  @override
  String get travelConfirmTitle => 'Apply journey';

  @override
  String travelConfirmBody(Object duration, Object miles, Object route) {
    return '$route\n\n$miles miles — $duration';
  }

  @override
  String travelAdvanceCalendar(Object days) {
    return 'Advance calendar $days days';
  }

  @override
  String travelAnnounce(Object days) {
    return 'The party travelled for $days days.';
  }

  @override
  String get travelDrawRoute => 'Draw route on map';

  @override
  String get travelDrawRouteHint =>
      'Tap the map to add a stop; tapping a pin turns it into a stop. At least two stops are needed.';

  @override
  String travelDrawRouteStops(int count) {
    return '$count stops selected. Use “Plan” to work out distance and time.';
  }

  @override
  String get travelRouteUndo => 'Remove last stop';

  @override
  String get travelRoutePlan => 'Plan';

  @override
  String travelWaypoint(int index) {
    return 'Waypoint $index';
  }

  @override
  String get journeyStart => 'Set out';

  @override
  String journeyStarted(String route, String miles) {
    return 'Journey started: $route ($miles miles)';
  }

  @override
  String get journeyTitle => 'Journey';

  @override
  String get journeyNone => 'No journey in progress.';

  @override
  String get journeyOpen => 'Open journey';

  @override
  String get journeyTotal => 'Total';

  @override
  String get journeyTravelled => 'Travelled';

  @override
  String get journeyRemaining => 'Remaining';

  @override
  String get journeyContinue => 'Continue';

  @override
  String get journeyPause => 'Stop here';

  @override
  String get journeyAbandon => 'End journey';

  @override
  String get journeyAbandonConfirm =>
      'The journey will be closed. Distance covered and days already spent are not undone.';

  @override
  String get journeyArrived => 'You have arrived.';

  @override
  String journeyArrivedLog(String route, String miles) {
    return 'Arrival: $route ($miles miles)';
  }

  @override
  String get journeyEncounterTitle => 'Something happened — the party stopped';

  @override
  String journeyDaysPassed(int days) {
    return '$days days passed in this stretch.';
  }

  @override
  String journeyBannerProgress(String travelled, String total) {
    return 'Journey in progress — $travelled / $total miles';
  }

  @override
  String journeySpeedLine(String mph, String hours) {
    return '$mph mph · $hours hours a day';
  }

  @override
  String get travelEncounters => 'Random encounters';

  @override
  String get travelEncountersHint =>
      'A d20 is rolled for every stretch of the journey; each roll that meets the threshold draws a line from the chosen table. Results are shown to you only.';

  @override
  String get travelEncounterTable => 'Encounter table';

  @override
  String get travelEncounterNoTables =>
      'No random tables yet. Add one from the Tables tab.';

  @override
  String travelEncounterChance(int threshold, int percent) {
    return 'Threshold: d20 ≥ $threshold  ($percent%)';
  }

  @override
  String get travelEncounterChecks => 'Checks per day';

  @override
  String travelEncounterWhen(int day, int check) {
    return 'Day $day · check $check';
  }

  @override
  String travelEncounterMissingRow(int roll) {
    return 'No table row covers a roll of $roll.';
  }

  @override
  String travelEncounterLogged(int day, String text) {
    return 'Day $day — encounter: $text';
  }

  @override
  String get travelPaceFast => 'Fast';

  @override
  String get travelPaceNormal => 'Normal';

  @override
  String get travelPaceSlow => 'Slow';

  @override
  String get travelMountPony => 'Pony';

  @override
  String get travelMountDraftHorse => 'Draft Horse';

  @override
  String get travelMountMastiff => 'Mastiff';

  @override
  String get travelMountElephant => 'Elephant';

  @override
  String get travelMountCamel => 'Camel';

  @override
  String get travelMountRidingHorse => 'Riding Horse';

  @override
  String get travelMountWarhorse => 'Warhorse';

  @override
  String get travelVehicleRowboat => 'Rowboat';

  @override
  String get travelVehicleKeelboat => 'Keelboat';

  @override
  String get travelVehicleSailingShip => 'Sailing Ship';

  @override
  String get travelVehicleWarship => 'Warship';

  @override
  String get travelVehicleLongship => 'Longship';

  @override
  String get travelVehicleGalley => 'Galley';

  @override
  String get worldNpcAdd => 'Add NPC';

  @override
  String get worldNpcEmpty =>
      'No NPCs yet. Once added you can link them to map pins.';

  @override
  String get worldNpcNameLabel => 'Name';

  @override
  String get worldNpcRoleLabel => 'Role';

  @override
  String get worldNpcNoLinks =>
      'Not linked to any map yet. Link it by adding an NPC pin on a place\'s map.';

  @override
  String get worldNpcAppearsIn => 'Appears in';

  @override
  String get worldPinEdit => 'Edit pin';

  @override
  String get worldPinLabel => 'Label';

  @override
  String get worldPinLabelHint => 'e.g. Ruined tower';

  @override
  String get worldPinType => 'Type';

  @override
  String get worldPinNote => 'Note';

  @override
  String get worldPinNoteHint =>
      'Only you see it; if you reveal the pin, players do too.';

  @override
  String get worldPinRevealLocationHint =>
      'When off, the pin is visible only to you. When on, players can tap it to enter that place\'s map (if it has one).';

  @override
  String get worldPinRevealHint => 'When off, the pin is visible only to you.';

  @override
  String get worldKindLocation => 'Sub-location';

  @override
  String get worldKindNpc => 'NPC';

  @override
  String get worldKindShop => 'Shop';

  @override
  String get worldKindEncounter => 'Encounter';

  @override
  String get worldKindTreasure => 'Treasure';

  @override
  String get worldKindTreasureLoot => 'Loot preset';

  @override
  String get worldKindTreasureLootHint =>
      'Players take items/coins from this preset by tapping the pin. The preset can\'t be changed later.';

  @override
  String get worldKindTreasureLootNone => 'Free note (no preset)';

  @override
  String get worldTreasureNoLootSets =>
      'No loot presets yet. Create one in the Loot tab.';

  @override
  String worldTreasureRemainingDetail(Object coins, Object items) {
    return 'Remaining loot: $items items, $coins cp';
  }

  @override
  String get worldTargetNoLocations =>
      'There are no sub-locations here yet. Create one via “Add sub-location” in the menu.';

  @override
  String get worldTargetNoNpcs =>
      'No NPCs yet. Add them from the NPC list on the World screen.';

  @override
  String get worldTargetNoShops =>
      'No shops yet. Set one up from the Shops tab.';

  @override
  String get worldTargetNoEncounters =>
      'No encounters yet. Create one from the Combat tab.';

  @override
  String get worldTargetLink => 'Record to link';

  @override
  String worldDeleteConfirmTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get sessionBackup => 'Backup';

  @override
  String get sessionCloseTable => 'Close session';

  @override
  String get sessionLogTitle => 'Session log';

  @override
  String get sessionLogAdd => 'Add note';

  @override
  String get sessionLogClear => 'Clear';

  @override
  String get sessionLogClearConfirm => 'Permanently clear the whole log?';

  @override
  String get sessionLogEmpty =>
      'No entries yet. XP awards and notes accumulate here.';

  @override
  String get sessionHandoutCaption => 'Image caption (optional)';

  @override
  String get sessionHandoutShow => 'Show image';

  @override
  String get sessionHandoutClear => 'Remove image';

  @override
  String get sessionHandoutShared => 'Image shown to players.';

  @override
  String get sessionHandoutCleared => 'Image removed.';

  @override
  String get codexNewPage => 'New page';

  @override
  String get codexUntitled => 'Untitled';

  @override
  String get codexAddSubpage => 'Add subpage';

  @override
  String get codexRename => 'Rename';

  @override
  String get codexSetIcon => 'Icon (emoji)';

  @override
  String codexDeleteConfirm(String title) {
    return 'Delete “$title” and all its subpages?';
  }

  @override
  String get codexEmpty => 'No pages yet';

  @override
  String get codexEmptyHint =>
      'Create your first page; add text, lists, images, tables, dice and links inside.';

  @override
  String get codexDone => 'Done';

  @override
  String get codexAddBlock => 'Add block';

  @override
  String get codexAddBlockHint => 'Add a block from the button below.';

  @override
  String get codexPageTitleEdit => 'Page title';

  @override
  String get codexPageEmpty => 'This page is empty.';

  @override
  String get codexAddItem => 'Add item';

  @override
  String get codexBlockText => 'Text';

  @override
  String get codexBlockHeading => 'Heading';

  @override
  String get codexBlockBulleted => 'Bulleted list';

  @override
  String get codexBlockChecklist => 'Checklist';

  @override
  String get codexBlockCallout => 'Callout';

  @override
  String get codexBlockTable => 'Table';

  @override
  String get codexBlockChart => 'Chart';

  @override
  String get codexBlockImage => 'Image';

  @override
  String get codexBlockVideo => 'Video';

  @override
  String get codexBlockLink => 'Link';

  @override
  String get codexVideoUpload => 'Upload video';

  @override
  String get codexVideoSelected => 'Video selected';

  @override
  String get codexVideoMissing => 'Video file missing';

  @override
  String get codexLinkUrl => 'URL';

  @override
  String codexLinkFailed(Object url) {
    return 'Couldn’t open $url';
  }

  @override
  String get codexChartTitle => 'Chart title';

  @override
  String get codexChartLabel => 'Label';

  @override
  String get codexChartValue => 'Value';

  @override
  String get codexSearchHint => 'Search codex...';

  @override
  String get codexBlockCharacter => 'Character card';

  @override
  String get codexCharacterMissing => 'Character not found';

  @override
  String codexCharacterLevel(int level) {
    return 'Level $level';
  }

  @override
  String get codexWikiMissingTitle => 'No such page';

  @override
  String codexWikiMissingBody(String title) {
    return 'No page named “$title”. Create it?';
  }

  @override
  String get codexWikiCreate => 'Create';

  @override
  String codexRefNotFound(String name) {
    return '“$name” not found.';
  }

  @override
  String get codexTextHint =>
      '**bold** · *italic* · `code` · [[Page]] · /r1d20 · /character(Name) · /monster(Name) · /spell(Name) · /item(Name) · /link(url)(word) · /page(Title)(word)';

  @override
  String get codexBlockDivider => 'Divider';

  @override
  String get codexBlockDice => 'Dice';

  @override
  String get codexBlockPageLink => 'Page link';

  @override
  String get codexBlockEntityLink => 'Entity link';

  @override
  String get codexBadExpression => 'Invalid dice expression (e.g. 2d6+3).';

  @override
  String get codexDiceLabel => 'Label';

  @override
  String get codexDiceExpression => 'Dice expression';

  @override
  String get codexTableHeader => 'Header row';

  @override
  String get codexTableAddRow => 'Row';

  @override
  String get codexTableAddColumn => 'Column';

  @override
  String get codexTableRemoveColumn => 'Remove column';

  @override
  String get codexImageCaption => 'Caption (optional)';

  @override
  String get codexLinkTargetPage => 'Target page';

  @override
  String get codexLinkLabel => 'Label (optional)';

  @override
  String get sessionOpenTable => 'Open the table';

  @override
  String get sessionStartHint =>
      'While on the same Wi-Fi network, players scan the QR code with their phone camera and connect from the browser. No app install, account, or internet needed.';

  @override
  String get sessionStartServer => 'Start server';

  @override
  String get sessionAddressCopied => 'Address copied';

  @override
  String get sessionCopyAddress => 'Copy address';

  @override
  String get sessionReject => 'Reject';

  @override
  String get sessionApprove => 'Approve';

  @override
  String get sessionDmTools => 'DM tools';

  @override
  String get sessionTarget => 'Target';

  @override
  String get sessionEveryone => 'Everyone';

  @override
  String get sessionAnnouncement => 'Announcement / message';

  @override
  String get sessionSend => 'Send';

  @override
  String get sessionAnnouncementSent => 'Announcement sent.';

  @override
  String get sessionAbility => 'Ability';

  @override
  String get sessionRequestSave => 'Request save';

  @override
  String get sessionSaveRequested => 'Saving throw requested.';

  @override
  String get sessionGold => 'Gold';

  @override
  String get sessionItemsCsv => 'Items (comma-separated)';

  @override
  String get sessionGiveLoot => 'Give loot';

  @override
  String get sessionLootOffered => 'Loot offered.';

  @override
  String get sessionNobodyConnected => 'Nobody has connected yet.';

  @override
  String get sessionNoCharacter => 'No character chosen';

  @override
  String get sessionHasCharacter => 'Claimed a character';

  @override
  String sessionPurchaseRequests(int count) {
    return 'Purchase request ($count)';
  }

  @override
  String sessionConnectedPlayers(int count) {
    return 'Connected players ($count)';
  }

  @override
  String get charactersTabParty => 'Party';

  @override
  String get charactersTabSharedInventory => 'Shared inventory';

  @override
  String get charactersNew => 'New character';

  @override
  String get charactersDelete => 'Delete character';

  @override
  String get charactersEmpty => 'No characters yet';

  @override
  String get charactersEmptyHint =>
      'Create your first character with the button at the bottom right.';

  @override
  String charactersDeleteConfirm(String name) {
    return '“$name” will be permanently deleted. Are you sure?';
  }

  @override
  String get compendiumCreateMonster => 'Create monster';

  @override
  String get compendiumImportImages => 'Import images';

  @override
  String get compendiumImportHint =>
      'Choose a folder; images whose file name matches a monster name (e.g. Goblin.png) are assigned automatically. Your own images only.';

  @override
  String get compendiumChooseFolder => 'Choose folder';

  @override
  String get compendiumNoImagesFound => 'No images found in the folder.';

  @override
  String compendiumImportResult(int assigned, int unmatched) {
    return '$assigned monsters got an image, $unmatched files unmatched.';
  }

  @override
  String get compendiumCreateSpell => 'Create spell';

  @override
  String get compendiumCreateItem => 'Create item';

  @override
  String get compendiumCreateMagicItem => 'Create magic item';

  @override
  String get compendiumCrRange => 'Challenge range';

  @override
  String get compendiumPrice => 'Price';

  @override
  String get compendiumWeight => 'Weight';

  @override
  String get compendiumDamage => 'Damage';

  @override
  String get compendiumProperties => 'Properties';

  @override
  String get compendiumStrengthReq => 'Strength req.';

  @override
  String get compendiumStealth => 'Stealth';

  @override
  String get compendiumDisadvantage => 'Disadvantage';

  @override
  String get compendiumSuggested => 'suggested';

  @override
  String get compendiumMagicPriceHint =>
      'The SRD doesn\'t publish prices for magic items; this value is suggested by rarity and can be changed when setting up a shop.';

  @override
  String get levelUpNoClass => 'The character has no class.';

  @override
  String get levelUpNewClass => 'new class';

  @override
  String get levelUpFeaturesGained => 'Features gained';

  @override
  String get levelUpWhichClass => 'Which class are you advancing?';

  @override
  String get levelUpHitPoints => 'Hit points';

  @override
  String get levelUpSubclass => 'Subclass';

  @override
  String get levelUpAddCustom => 'Add my own';

  @override
  String get levelUpAbilityIncrease => 'Ability score increase';

  @override
  String get levelUpRoll => 'Roll';

  @override
  String levelUpSaveAs(String className, int level) {
    return 'Save as $className $level';
  }

  @override
  String levelUpHpHint(int sides, int avg) {
    return 'Roll d$sides or take the fixed $avg. Your CON modifier is added on top of this value.';
  }

  @override
  String levelUpFixed(int avg) {
    return 'Fixed $avg';
  }

  @override
  String levelUpRolled(int n) {
    return 'Roll: $n';
  }

  @override
  String levelUpAbilityHint(int remaining) {
    return '+2 to one ability or +1 to two. Remaining: $remaining';
  }

  @override
  String get lootNewSet => 'New set';

  @override
  String get lootEmpty =>
      'No loot sets yet. Prepare a set with items and money, then offer it to players with a single tap at the table.';

  @override
  String get lootEmptyLabel => 'Empty';

  @override
  String get lootShow => 'Show';

  @override
  String get lootSetTitle => 'Loot set';

  @override
  String get lootSetName => 'Set name';

  @override
  String get lootMoney => 'Money';

  @override
  String get lootItems => 'Items';

  @override
  String get lootNoItems => 'No items yet.';

  @override
  String get lootAddItem => 'Add item';

  @override
  String get lootMagic => 'Magic';

  @override
  String get lootAddFromCompendium => 'Add from catalog';

  @override
  String lootItemCount(int count) {
    return '$count items';
  }

  @override
  String get lootUnknownItem => 'Unknown item';

  @override
  String get navTables => 'Tables';

  @override
  String get navTablesShort => 'Tables';

  @override
  String get tablesTabTables => 'Tables';

  @override
  String get tablesTabNames => 'Name generator';

  @override
  String get tablesNew => 'New table';

  @override
  String get tablesEmpty =>
      'No tables yet. Build your own (d4–d100), enter the rows, and roll on it at the table with one tap.';

  @override
  String get tablesEditTitle => 'Edit table';

  @override
  String get tablesName => 'Table name';

  @override
  String get tablesCategory => 'Category';

  @override
  String get tablesCategoryHint => 'e.g. town, road, loot';

  @override
  String get tablesDice => 'Die';

  @override
  String get tablesRows => 'Rows';

  @override
  String get tablesAddRow => 'Add row';

  @override
  String tablesRowCount(Object count) {
    return '$count rows';
  }

  @override
  String get tablesRoll => 'Roll';

  @override
  String get tablesRollAgain => 'Roll again';

  @override
  String get tablesNoRowForRoll =>
      'No row covers this number (the table has a gap).';

  @override
  String get tablesRedistribute => 'Distribute ranges';

  @override
  String tablesDeleteConfirm(Object name) {
    return 'Delete the table “$name”?';
  }

  @override
  String get tablesIssueGap => 'Some die faces aren\'t covered by any row.';

  @override
  String get tablesIssueOverlap =>
      'Some numbers are covered by more than one row.';

  @override
  String get tablesIssueOutOfRange =>
      'Some rows fall outside the die\'s range.';

  @override
  String get tablesIssueEmptyRange => 'A row starts after it ends.';

  @override
  String get nameGeneratorHint =>
      'Runs fully offline; builds names from syllables and words, and never repeats one.';

  @override
  String get nameCount => 'Count';

  @override
  String get nameGenerate => 'Generate';

  @override
  String get nameCopy => 'Copy';

  @override
  String nameCopied(Object name) {
    return 'Copied “$name”.';
  }

  @override
  String get nameSaveAsNpc => 'Save as NPC';

  @override
  String nameSavedAsNpc(Object name) {
    return 'Saved “$name” as an NPC.';
  }

  @override
  String get nameSaveAsLocation => 'Save as location';

  @override
  String nameSavedAsLocation(String name) {
    return 'Added “$name” to locations.';
  }

  @override
  String get nameGender => 'Gender';

  @override
  String get nameGenderAny => 'Any';

  @override
  String get nameGenderMale => 'Male';

  @override
  String get nameGenderFemale => 'Female';

  @override
  String get nameSurname => 'Add surname / epithet';

  @override
  String get nameCategoryPerson => 'People';

  @override
  String get nameCategoryPlace => 'Places';

  @override
  String get nameCategoryEstablishment => 'Businesses';

  @override
  String get nameCategoryGroup => 'Groups';

  @override
  String get nameCategoryThing => 'Things';

  @override
  String get nameCultureHuman => 'Human';

  @override
  String get nameCultureHumanNorth => 'Human (northern)';

  @override
  String get nameCultureHumanDesert => 'Human (desert)';

  @override
  String get nameCultureHumanEast => 'Human (eastern)';

  @override
  String get nameCultureElf => 'Elf';

  @override
  String get nameCultureDrow => 'Drow';

  @override
  String get nameCultureDwarf => 'Dwarf';

  @override
  String get nameCultureHalfling => 'Halfling';

  @override
  String get nameCultureGnome => 'Gnome';

  @override
  String get nameCultureOrc => 'Orc';

  @override
  String get nameCultureGoblin => 'Goblin';

  @override
  String get nameCultureTiefling => 'Tiefling';

  @override
  String get nameCultureDragonborn => 'Dragonborn';

  @override
  String get nameCultureGoliath => 'Goliath';

  @override
  String get nameCultureLizardfolk => 'Lizardfolk';

  @override
  String get nameCultureTabaxi => 'Tabaxi';

  @override
  String get nameCultureCelestial => 'Celestial';

  @override
  String get nameCultureUndead => 'Undead';

  @override
  String get nameCulturePlace => 'Town / village';

  @override
  String get nameCultureCity => 'City';

  @override
  String get nameCultureFortress => 'Fortress';

  @override
  String get nameCultureRuin => 'Ruin';

  @override
  String get nameCultureForest => 'Forest';

  @override
  String get nameCultureMountain => 'Mountain';

  @override
  String get nameCultureWater => 'River / lake';

  @override
  String get nameCultureIsland => 'Island';

  @override
  String get nameCultureRegion => 'Region';

  @override
  String get nameCultureTavern => 'Tavern';

  @override
  String get nameCultureShop => 'Shop';

  @override
  String get nameCultureTemple => 'Temple';

  @override
  String get nameCultureGuild => 'Guild';

  @override
  String get nameCultureNobleHouse => 'Noble house';

  @override
  String get nameCultureMercenary => 'Mercenary company';

  @override
  String get nameCultureCult => 'Cult';

  @override
  String get nameCultureShip => 'Ship';

  @override
  String get nameCultureMagicItem => 'Magic item';

  @override
  String get nameCultureTome => 'Book / tome';

  @override
  String get nameCultureFestival => 'Festival';

  @override
  String get nameCultureEpithet => 'Title / epithet';

  @override
  String get aiToolTable => 'Table';

  @override
  String get aiTableTopic => 'Topic / theme';

  @override
  String get aiTableTopicHint =>
      'e.g. random events in a swamp, rumours in a port city';

  @override
  String get aiTableRowCount => 'Row count';

  @override
  String get aiTableTone => 'Tone';

  @override
  String get aiTableToneGritty => 'Gritty';

  @override
  String get aiTableToneHumorous => 'Humorous';

  @override
  String get aiTableToneEpic => 'Epic';

  @override
  String get aiTableToneMundane => 'Mundane';

  @override
  String get aiTableContext => 'Extra context (optional)';

  @override
  String get aiTableContextHint =>
      'Details specific to your campaign; rows are written around them.';

  @override
  String get aiTableSave => 'Save to tables';

  @override
  String get aiTableSaved => 'Saved';

  @override
  String aiTableSavedTo(Object name) {
    return 'Saved “$name” to Tables.';
  }

  @override
  String get partyInventoryTitle => 'Shared purse';

  @override
  String get partyInventoryNew => 'New purse';

  @override
  String get partyInventoryEmpty =>
      'No shared purses yet. Create one and pick its members; they can freely take and deposit items and coins from their own panels.';

  @override
  String get partyInventoryName => 'Purse name';

  @override
  String get partyInventoryMembers => 'Members';

  @override
  String get partyInventoryMembersHint =>
      'Only the players you pick can see and use this purse.';

  @override
  String get partyInventoryNoCharacters => 'No characters yet.';

  @override
  String partyInventoryMembersCount(Object count) {
    return '$count members';
  }

  @override
  String get partyInventoryNoMembers => 'No members';

  @override
  String get partyInventoryCoins => 'Coins';

  @override
  String get partyInventoryItems => 'Items';

  @override
  String partyInventoryDeleteConfirm(Object name) {
    return 'Delete the purse “$name”? Its contents go too.';
  }

  @override
  String lootOffered(String name) {
    return '“$name” offered to players.';
  }

  @override
  String get shopsNew => 'New shop';

  @override
  String get shopsOpen => 'Open to players';

  @override
  String get shopsClosed => 'Closed';

  @override
  String get shopsName => 'Shop name';

  @override
  String get shopsNameHint => 'e.g. Blacksmith';

  @override
  String get shopsOwner => 'Operator (optional)';

  @override
  String get shopsOwnerHint => 'Free text — or pick an existing NPC above.';

  @override
  String get shopsOwnerNpc => 'Operating NPC';

  @override
  String get shopsOwnerNpcNone => 'None (free text)';

  @override
  String get shopsEmpty => 'No shops';

  @override
  String get shopsEmptyHint =>
      'Build a shop by picking items from the library, then open it to players.';

  @override
  String get formName => 'Name';

  @override
  String get formDescription => 'Description';

  @override
  String get formLevel => 'Level';

  @override
  String get formRange => 'Range';

  @override
  String get formDuration => 'Duration';

  @override
  String get formMaterial => 'Material (M)';

  @override
  String get formClasses => 'Classes';

  @override
  String get formClassesFailed => 'Could not load class list.';

  @override
  String get formHigherLevel => 'At higher level (optional)';

  @override
  String get formCastingTimeHint => 'e.g. 1 action';

  @override
  String get formRangeHint => 'e.g. 60 feet';

  @override
  String get formDurationHint => 'e.g. Instantaneous';

  @override
  String get formMaterialHint => 'e.g. a pinch of sulfur';

  @override
  String get ccAddSpecies => 'Add species';

  @override
  String get ccSpeciesName => 'Species name';

  @override
  String get ccSize => 'Size';

  @override
  String get ccSpeed => 'Speed (feet)';

  @override
  String get ccTraits => 'Traits (free text)';

  @override
  String get ccSubclassName => 'Subclass name';

  @override
  String get ccSubclassNameHint => 'e.g. Battle Master';

  @override
  String get ccSubclassTraitsHint =>
      'You can write the level-by-level features here.';

  @override
  String get ccAddBackground => 'Add background';

  @override
  String get ccBackgroundName => 'Background name';

  @override
  String get ccToolProf => 'Tool proficiency (optional)';

  @override
  String get ccBackgroundFeat => 'Background feat (optional)';

  @override
  String ccAddSubclass(String className) {
    return 'Add $className subclass';
  }

  @override
  String ccAbilities3(int count) {
    return 'Abilities — exactly 3 ($count/3)';
  }

  @override
  String ccSkills2(int count) {
    return 'Skills — exactly 2 ($count/2)';
  }

  @override
  String get ciMagicPrice => 'Price (suggested by rarity if left blank)';

  @override
  String get ciAttunement => 'Requires attunement';

  @override
  String get ciFreeStock => 'Free line';

  @override
  String get ciFreeStockHint =>
      'Visible only in this shop, not saved to the library.';

  @override
  String get ciQuantity => 'Quantity (-1 unlimited)';

  @override
  String get mcType => 'Type';

  @override
  String get mcArmorClass => 'Armor class';

  @override
  String get mcSpeedFt => 'Speed (ft)';

  @override
  String get mcAbilityScores => 'Ability scores';

  @override
  String get mcAttackPower => 'Attack power';

  @override
  String get mcAttackHint =>
      'For the CR estimate: how much damage on average per round, and what is the attack bonus?';

  @override
  String get mcDamagePerRound => 'Damage per round';

  @override
  String get mcAttackBonus => 'Attack bonus';

  @override
  String get mcSaveToLibrary => 'Save to library';

  @override
  String get mcEstimatedCr => 'Estimated challenge';

  @override
  String get mcBenchmarkNote =>
      'The benchmarks are derived from the real stats of 331 monsters in SRD 5.2. This is a starting point — special abilities and encounter design change the real difficulty.';

  @override
  String get mcActions => 'Actions';

  @override
  String get mcNoActions =>
      'No actions yet. Add the attacks and abilities that will appear in the stat block here.';

  @override
  String get mcAddAction => 'Add action';

  @override
  String get mcActionNameHint => 'e.g. Bite';

  @override
  String mcCrBreakdown(String defensive, String offensive) {
    return 'Defense CR $defensive · Offense CR $offensive';
  }

  @override
  String get seShortDesc => 'Short description (optional)';

  @override
  String get seFeaturesHint =>
      'What is gained at which level. These come automatically on level-up and appear on the character sheet.';

  @override
  String get seNoFeatures => 'No features added yet.';

  @override
  String get seResources => 'Counters';

  @override
  String get seResourcesHint =>
      'Values that grow by level: superiority dice, ki points, uses… They appear as counters on the character sheet.';

  @override
  String get seNoResources => 'No counters. Most subclasses don\'t need them.';

  @override
  String get seAddFeature => 'Add feature';

  @override
  String get seFeatureName => 'Feature name';

  @override
  String get seFeatureNameHint => 'e.g. Combat Superiority';

  @override
  String get seFeatureDesc => 'What does it do?';

  @override
  String get seAddResource => 'Add counter';

  @override
  String get seResourceName => 'Counter name';

  @override
  String get seResourceNameHint => 'e.g. Superiority Die';

  @override
  String get seResourceHint =>
      'Only enter the levels where it changes; the levels in between are filled in automatically.';

  @override
  String get seAddThreshold => 'Add change point';

  @override
  String get seThreshold => 'Change point';

  @override
  String get seValue => 'Value';

  @override
  String get seValueHint => 'e.g. 4  or  1d8';

  @override
  String seSubclassOf(String className) {
    return '$className subclass';
  }

  @override
  String seLevelArrow(int level, String value) {
    return 'lvl $level → $value';
  }

  @override
  String get sdAddFromLibrary => 'Add from library';

  @override
  String get sdCreateOwnItem => 'Create your own item';

  @override
  String get sdCreateOwnMagic => 'Create your own magic item';

  @override
  String get sdAddFreeLine => 'Add free line';

  @override
  String get sdStockEmpty =>
      'Stock is empty. Add items from the buttons at the top right.';

  @override
  String get sdPriceMultiplier => 'Price multiplier';

  @override
  String get sdPriceMultiplierHint =>
      'Applied to list prices. Lower it when haggling, raise it in a remote town.';

  @override
  String get sdOpenToPlayers => 'Open to players';

  @override
  String get sdOpenHint =>
      'When on, this shop appears in players\' panels. Only one shop can be open at a time.';

  @override
  String get sdMapAccessible => 'Accessible from map';

  @override
  String get sdMapAccessibleHint =>
      'When on, players can open this shop by tapping its pin on a visible map. Multiple shops can be accessible at once.';

  @override
  String get sdClosed => 'Shop closed';

  @override
  String get sdClosedHint =>
      'When closed, players see “shop closed” on tap; items aren\'t listed and can\'t be bought.';

  @override
  String get sdRequireApproval => 'Require purchase approval';

  @override
  String get sdRequireApprovalHint =>
      'When off, players buy directly; their gold and the stock drop immediately.';

  @override
  String get sdUnlimited => 'unlimited';

  @override
  String get sdEditPrice => 'Edit price';

  @override
  String get sdEditQuantity => 'Edit quantity';

  @override
  String get sdMakeUnlimited => 'Make unlimited';

  @override
  String get sdRestock => 'Restocking';

  @override
  String get sdRestockHint =>
      'How many in-game days between restocks? Shops whose timer runs out restock on their own as the calendar advances.';

  @override
  String get sdRestockOff => 'Off';

  @override
  String sdRestockEvery(int days) {
    return 'Every $days days';
  }

  @override
  String get sdRestockQty => 'Restock amount';

  @override
  String sdRestockQtyTitle(String name) {
    return '$name — amount after restock';
  }

  @override
  String get sdRestockQtyHint =>
      'The quantity returns to this value on restock. If you leave it unset the line never restocks — once it sells out, it is gone.';

  @override
  String get sdRestockQtyClear => 'Never restock this line';

  @override
  String sdRestockQtyBadge(int count) {
    return 'restock: $count';
  }

  @override
  String shopRestocked(String shops) {
    return 'Restocked: $shops';
  }

  @override
  String sdOperator(String name) {
    return 'Operator: $name';
  }

  @override
  String get sdOperatorNone => 'No operator set';

  @override
  String get sdOpenOwnerNpc => 'Open NPC card';

  @override
  String sdPieces(int count) {
    return '$count pcs';
  }

  @override
  String sdPriceTitle(String name) {
    return '$name — price';
  }

  @override
  String sdQtyTitle(String name) {
    return '$name — quantity';
  }

  @override
  String get cwStepIdentity => 'Identity and species';

  @override
  String get cwStepBackground => 'Background';

  @override
  String get cwStepClass => 'Class';

  @override
  String get cwStepEquipment => 'Starting equipment';

  @override
  String get cwStepSummary => 'Summary';

  @override
  String get cwNext => 'Next';

  @override
  String get cwCreateCharacter => 'Create character';

  @override
  String get cwCharacterName => 'Character name';

  @override
  String get cwPlayerName => 'Player name (optional)';

  @override
  String get cwAddPhoto => 'Add photo';

  @override
  String get cwSpecies => 'Species';

  @override
  String get cwChooseSize => 'Choose size';

  @override
  String get cwBackground => 'Background';

  @override
  String get cwTool => 'Tool';

  @override
  String get cwBackgroundFeat => 'Background feat';

  @override
  String get cwAbilityIncrease3 => 'Ability score increase (3 points)';

  @override
  String get cwOriginPointsHint =>
      'In the 2024 rules the background gives 3 points: either +2 to one ability and +1 to another, or +1 to three.';

  @override
  String get cwHitDie => 'Hit die';

  @override
  String get cwWeapons => 'Weapons';

  @override
  String get cwArmor => 'Armor';

  @override
  String get cwTools => 'Tools';

  @override
  String get cwSubclassLater =>
      'The subclass is chosen at level 3 — it will come in the level-up flow.';

  @override
  String get cwSelectionDone => 'Selection complete';

  @override
  String get cwChooseClassFirst => 'Choose a class first.';

  @override
  String get cwEquipmentHint =>
      'The same-letter option from your class and background is taken together.';

  @override
  String get cwEquipmentNote =>
      'The items and gold you choose are added to the inventory automatically; you can edit them later from the inventory section of the character sheet.';

  @override
  String get cwUnnamed => 'Unnamed';

  @override
  String get cwPointBuy => 'Point buy';

  @override
  String get cwStandardArray => 'Standard array';

  @override
  String get cwManual => 'Manual';

  @override
  String get sheetUnknownItem => 'Unknown item';

  @override
  String get pfInvalidQuantity => 'Invalid quantity.';

  @override
  String get pfItemNotFound => 'Item not found.';

  @override
  String get pfShopNotFound => 'Shop not found.';

  @override
  String get pfShopClosed => 'The shop is currently closed.';

  @override
  String get pfSoldOut => 'This item is sold out.';

  @override
  String get pfCharacterNotFound => 'Character not found.';

  @override
  String get pfRequestNotFound => 'Request not found.';

  @override
  String pfOnlyNLeft(String n) {
    return 'Only $n left in stock.';
  }

  @override
  String pfNotEnoughGold(String need, String have) {
    return 'Not enough gold: $need needed, you have $have.';
  }

  @override
  String cwPointsRemaining(int n) {
    return 'Points remaining: $n';
  }

  @override
  String cwChooseMoreSkills(int n) {
    return 'Choose $n more skills from your class';
  }

  @override
  String cwFromBackground(String skills) {
    return 'Already from your background: $skills';
  }

  @override
  String cwOption(String label) {
    return 'Option $label';
  }

  @override
  String cwBackgroundPrefix(String desc) {
    return 'Background: $desc';
  }

  @override
  String get backupExport => 'Create a backup';

  @override
  String get backupExportHint =>
      'Characters, NPCs, worlds, Codex notes, player notes, inventories, quests, session log and content you added are written to a single file. Images are embedded in the file itself, not just referenced. The rules library (SRD) is not included — the app already carries it internally.';

  @override
  String get backupCreateFile => 'Create backup file';

  @override
  String get backupExportedHint =>
      'Copy this file to a computer or upload it to the cloud; if you delete the app, the copy on the device is gone too.';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String get backupRestoreHint =>
      'Your current characters, encounters, shops and maps will be REPLACED with the ones in the backup. Records not in the backup are deleted.';

  @override
  String get backupPickFile => 'Choose backup file';

  @override
  String get backupWillReplace =>
      'Your existing data will be replaced with these.';

  @override
  String get backupRestoreButton => 'Restore';

  @override
  String get backupRestored => 'Backup restored.';

  @override
  String get backupFileType => 'Backup';

  @override
  String get backupLabelCharacters => 'Characters';

  @override
  String get backupLabelEncounters => 'Encounters';

  @override
  String get backupLabelCombatants => 'Combatants';

  @override
  String get backupLabelShops => 'Shops';

  @override
  String get backupLabelShopStock => 'Shop entries';

  @override
  String get backupLabelLocations => 'Locations';

  @override
  String get backupLabelMapPins => 'Map pins';

  @override
  String get backupLabelNpcs => 'NPCs';

  @override
  String get backupLabelMonsters => 'Your monsters';

  @override
  String get backupLabelItems => 'Your items';

  @override
  String get backupLabelMagicItems => 'Your magic items';

  @override
  String get backupLabelClasses => 'Your classes/subclasses';

  @override
  String get backupLabelSpecies => 'Your species';

  @override
  String get backupLabelBackgrounds => 'Your backgrounds';

  @override
  String get backupLabelCodexPages => 'Codex pages';

  @override
  String get backupLabelCodexBlocks => 'Codex blocks';

  @override
  String get backupLabelClassLevels => 'Class levels';

  @override
  String get backupLabelProficiencies => 'Proficiencies';

  @override
  String get backupLabelInventory => 'Inventory';

  @override
  String get backupLabelCharacterSpells => 'Spells';

  @override
  String get backupLabelCharacterFeatures => 'Features';

  @override
  String get backupLabelPlayerNotes => 'Player notes';

  @override
  String get backupLabelLootSets => 'Loot sets';

  @override
  String get backupLabelQuests => 'Quests';

  @override
  String get backupLabelWorldLinks => 'World links';

  @override
  String get backupLabelBondTypes => 'Bond types';

  @override
  String get backupLabelFeats => 'Feats';

  @override
  String get backupLabelSessionLog => 'Session log';

  @override
  String backupExportedKb(int kb) {
    return 'Backup created: $kb KB';
  }

  @override
  String backupExportFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String backupReadFailed(String error) {
    return 'This file could not be read: $error';
  }

  @override
  String backupDate(String date) {
    return 'Date: $date';
  }

  @override
  String backupMapFiles(int count) {
    return 'Map files: $count';
  }

  @override
  String backupPortraitFiles(int count) {
    return 'Portrait files: $count';
  }

  @override
  String backupMediaFiles(Object count) {
    return 'Codex videos: $count';
  }

  @override
  String backupMusicFiles(int count) {
    return 'Music files: $count';
  }

  @override
  String get backupImportAsCampaign => 'Import as a new campaign';

  @override
  String get backupImportAsCampaignHint =>
      'Sets the backup up as a separate campaign; your open campaign is untouched. For taking someone else\'s table with you, or keeping an old save.';

  @override
  String get backupImportButton => 'Import';

  @override
  String backupImportedAsCampaign(String name) {
    return 'Campaign “$name” was created from the backup.';
  }

  @override
  String get backupOpenImportedCampaign =>
      'Switch to this campaign now? Your open table closes and players will need a new join address.';

  @override
  String get backupLabelPartyInventories => 'Party pouches';

  @override
  String get backupLabelRandomTables => 'Random tables';

  @override
  String get backupLabelJourneys => 'Journeys';

  @override
  String get backupLabelCalendar => 'Calendar structure';

  @override
  String get backupLabelEras => 'Eras';

  @override
  String get backupLabelChronicle => 'Chronicle events';

  @override
  String get backupLabelReminders => 'Reminders';

  @override
  String get backupLabelMusicPlaylists => 'Music lists';

  @override
  String get backupLabelMusicTracks => 'Music tracks';

  @override
  String get backupLabelSpells => 'Spells';

  @override
  String backupRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String sheetOrdinalLevel(int n) {
    return 'Level $n';
  }

  @override
  String sheetAbilityCheck(String ability) {
    return '$ability check';
  }

  @override
  String sheetAbilitySave(String ability) {
    return '$ability save';
  }

  @override
  String sheetTempHp(int n) {
    return '+$n temp';
  }

  @override
  String sheetPactMagic(int n) {
    return 'Pact Magic (lvl $n)';
  }

  @override
  String sheetExhaustionPenalty(int n) {
    return 'A $n penalty applies to all d20 tests.';
  }

  @override
  String sheetHitDieHealed(int n) {
    return 'Healed $n HP (1 hit die).';
  }

  @override
  String get diceTitle => 'Dice';

  @override
  String get diceCritical => 'Critical!';

  @override
  String get diceFumble => 'Failure!';

  @override
  String get navNpcs => 'NPCs';

  @override
  String get aiToolNpcTab => 'NPC';

  @override
  String get npcProfession => 'Profession';

  @override
  String get npcProfessionHint => 'blacksmith, innkeeper, guard...';

  @override
  String get npcGender => 'Gender';

  @override
  String get npcGenderMale => 'Male';

  @override
  String get npcGenderFemale => 'Female';

  @override
  String get npcGenderOther => 'Other';

  @override
  String get npcGenderRandom => 'Random';

  @override
  String get npcRace => 'Species / race';

  @override
  String get npcRaceHint => 'human, dwarf, elf... (blank = any)';

  @override
  String get npcName => 'Name (optional)';

  @override
  String get npcNameHint => 'leave blank to auto-generate';

  @override
  String get npcExtra => 'Extra details';

  @override
  String get npcExtraHint => 'personality, location, plot ties, tone...';

  @override
  String get npcHeading => 'NPC';

  @override
  String get npcSectionAppearance => 'Appearance';

  @override
  String get npcSectionPersonality => 'Personality';

  @override
  String get npcTraitIdeal => 'Ideal';

  @override
  String get npcTraitBond => 'Bond';

  @override
  String get npcTraitFlaw => 'Flaw';

  @override
  String get npcSectionHook => 'Roleplay hook';

  @override
  String get npcSectionSecret => 'Secret (DM only)';

  @override
  String get npcSaveToNpcs => 'Save to NPCs';

  @override
  String get npcSavedToNpcs => 'Saved to NPCs';

  @override
  String get worldGraphConnect => 'Connect';

  @override
  String get worldGraphConnectHint =>
      'Tap two nodes to link · tap an edge for menu';

  @override
  String get worldGraphChangeType => 'Change type';

  @override
  String get worldGraphDeleteLink => 'Remove bond';

  @override
  String get worldGraphOpenLocation => 'Open location';

  @override
  String get worldGraphShowToPlayers => 'Show to players';

  @override
  String get worldGraphHideFromPlayers => 'Hide from players';

  @override
  String worldGraphShownNotice(String name) {
    return '$name is now visible to players.';
  }

  @override
  String worldGraphHiddenNotice(String name) {
    return '$name is now hidden from players.';
  }

  @override
  String get worldGraphSetSize => 'Node radius';

  @override
  String get worldGraphSizeHint => 'Enter visual radius of selected node';

  @override
  String get worldGraphNodeRadiusLabel => 'Radius';

  @override
  String get worldDeleteNpc => 'Delete this NPC';

  @override
  String get bondRoad => 'Road / Neutral';

  @override
  String get bondFriendship => 'Friendship';

  @override
  String get bondEnmity => 'Enmity';

  @override
  String get bondTrade => 'Trade';

  @override
  String get bondFamily => 'Family';

  @override
  String get bondAlliance => 'Alliance';

  @override
  String get bondRivalry => 'Rivalry';

  @override
  String get bondLove => 'Love';

  @override
  String get bondVassalage => 'Vassalage';

  @override
  String get npcAge => 'Age';

  @override
  String get npcAlignment => 'Alignment';

  @override
  String get npcAddPortrait => 'Add portrait';

  @override
  String get npcChangePortrait => 'Change portrait';

  @override
  String get npcNotes => 'Notes';

  @override
  String get npcSecretLabel => 'Secret (DM only)';

  @override
  String get bondSettingsTitle => 'Bond types';

  @override
  String get bondNewType => 'New type';

  @override
  String get bondColorLabel => 'Color';

  @override
  String get bondHexLabel => 'Hex';

  @override
  String get bondBrightness => 'Brightness';

  @override
  String get navMore => 'More';

  @override
  String get navMoreTitle => 'All sections';

  @override
  String get navGroupTable => 'At the table';

  @override
  String get navGroupWorld => 'World & lore';

  @override
  String get navGroupTools => 'Tools';

  @override
  String get stateErrorTitle => 'Something went wrong';

  @override
  String get stateErrorMessage =>
      'This section could not be loaded. Try again; if it keeps failing, the technical detail below helps track it down.';

  @override
  String get stateErrorDetail => 'Technical detail';

  @override
  String get stateRetry => 'Try again';

  @override
  String get stateLoading => 'Loading…';

  @override
  String get npcBoundLocation => 'Bound location';

  @override
  String get npcBoundLocationNone => 'No location selected';

  @override
  String get npcBoundLocationHint =>
      'If set, the NPC is linked to this place on the map and the text is written around it.';

  @override
  String get npcNoLocations => 'No places yet. Add one from the World tab.';

  @override
  String get npcRelations => 'Relationships';

  @override
  String get npcRelationsHint =>
      'Link to as many NPCs as you like; the bond types are the same ones used on the map graph.';

  @override
  String get npcAddRelation => 'Add relationship';

  @override
  String get npcRemoveRelation => 'Remove relationship';

  @override
  String get npcRelationPickNpc => 'Pick NPC';

  @override
  String get npcNoOtherNpcs =>
      'No other NPCs to link to. Add some from the NPCs tab first.';

  @override
  String get npcPortraitToggle => 'Generate portrait';

  @override
  String get npcPortraitToggleHint =>
      'When on, a portrait is painted from the generated character\'s appearance, race, age and temperament.';

  @override
  String npcPortraitUnsupported(Object provider) {
    return '$provider does not generate images. Pick Gemini or OpenAI in Settings for portraits.';
  }

  @override
  String get npcPortraitGenerating => 'Painting the portrait…';

  @override
  String npcPortraitFailed(Object reason) {
    return 'Portrait could not be generated: $reason';
  }

  @override
  String get npcPortraitRegenerate => 'Regenerate portrait';

  @override
  String get npcPortraitTitle => 'Portrait';

  @override
  String npcSavedWithLinks(Object count) {
    return 'NPC saved ($count bonds created).';
  }

  @override
  String get aiImageModel => 'Image model';

  @override
  String get aiImageModelHint =>
      'Used for portrait generation. Leave empty to use the default.';

  @override
  String get aiImageUnsupportedNote =>
      'The selected provider does not generate images; portrait generation is off.';

  @override
  String get aiErrorDetail => 'Provider response';

  @override
  String get codexAiErrNoImage => 'This provider does not generate images.';
}
