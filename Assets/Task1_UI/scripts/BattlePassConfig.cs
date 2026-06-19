using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(menuName = "Battle Pass/Battle Pass Config")]
public class BattlePassConfig : ScriptableObject
{
    [Header("Season")]
    public string seasonName = "Season 16";
    public string heroName = "Cleopatra";
    public string rarityName = "Mythic";
    public string timeLeft = "17d 20h";

    [Header("Player Progress")]
    public int playerLevel = 3;
    public int currentXP = 80;
    public int requiredXP = 200;
    public bool premiumOwned;

    [Header("Currencies")]
    public int coins = 3403;
    public int diamonds = 18;
    public int luckyGems = 0;

    [Header("Free Rewards")]
    [Tooltip("Placed at milestone checkpoints on the road.")]
    public List<BattlePassRewardData> freeRewards = new();

    [Header("Premium Rewards")]
    [Tooltip("Continuous rewards shown in the top row.")]
    public List<BattlePassRewardData> premiumRewards = new();
}