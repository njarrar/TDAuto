# Playtest: starter stage, Mac, 2026-11-05

Player: the user (project owner). Machine: Mac16,10, Apple M4, macOS 26.6.2,
Godot 4.7.2, Mobile renderer on Metal, window 540x960, mouse as touch.

## Round 1 (normal bounty 4)
- Works: field, path and slots show; build arc opens and builds; enemies walk and
  towers fire; hero drag pins; win/lose screen and Retry work.
- Feedback: "price per tower is too high compared to the reward from killing an enemy".
- Change: normal bounty 4 to 5 (commit 12f7ed6).

## Round 2 (bounty 5)
- Feedback: start buys only two single towers; rewards too low; enemies take too many
  shots.
- Finding: at 125 HP a level-1 single needed 6.25 s per normal, which stays in range
  about 5 s.
- Change: starting gold 160; bounties 7, 4, 24; enemy HP 90, 45, 540 (commit 7f23f8e).

## Round 3 (rebalanced)
- Feedback: "it looks good now". New issue: with every slot full, a tower cannot be
  changed or grown further.
- User choices: sell for 70%, a third level, a panel with no time limit.
- Change: commit 3e0f65d.

## Round 4 (panel, sell, level 3)
- Upgrade and Sell buttons appear and read well: yes.
- Sell and rebuild feels right at 70%: yes.
- Level 3 worth its price: yes.
- User: "worked excellent".

## Open
- Pillar 2 (no tower build wins without the hero) is unverified at the new values; the
  bot runs were not redone.
- Two Tower GDD gold gates fail by the user's choice (forced first buy; board never full).
- No retained screenshot yet for the visual evidence rule.
