using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class RewardNodeUI : MonoBehaviour
{
    [Header("Card")]
    [SerializeField] private Image cardBackground;
    [SerializeField] private Image rewardIcon;
    [SerializeField] private TMP_Text rewardNameText;

    [Header("Amount")]
    [SerializeField] private GameObject amountRoot;
    [SerializeField] private TMP_Text amountText;
    [SerializeField] private Image amountIcon;

    [Header("State Objects")]
    [SerializeField] private GameObject lockIcon;
    [SerializeField] private GameObject alertIcon;
    [SerializeField] private GameObject claimedCheck;
    [SerializeField] private GameObject glow;

    [Header("FX")]
    [SerializeField] private ParticleSystem claimableParticles;
    [SerializeField] private ParticleSystem claimBurstParticles;
    [SerializeField] private Animator animator;

    [Header("Button")]
    [SerializeField] private Button button;

    private BattlePassRewardData data;
    private RewardState currentState;
    private System.Action<BattlePassRewardData> onClaim;

    public void Setup(
        BattlePassRewardData rewardData,
        int playerLevel,
        bool premiumOwned,
        System.Action<BattlePassRewardData> claimCallback)
    {
        data = rewardData;
        onClaim = claimCallback;

        rewardNameText.text = data.displayName?.ToUpper() ?? "";
        rewardIcon.sprite = data.icon;

        bool hasAmount = data.amount > 0;
        if (amountRoot != null)
            amountRoot.SetActive(hasAmount);

        if (amountText != null)
            amountText.text = hasAmount ? data.amount.ToString() : "";

        if (amountIcon != null)
        {
            amountIcon.gameObject.SetActive(data.currencyIcon != null);
            amountIcon.sprite = data.currencyIcon;
        }

        currentState = CalculateState(playerLevel, premiumOwned);
        ApplyState(currentState);

        button.onClick.RemoveAllListeners();
        button.onClick.AddListener(Claim);
    }

    private RewardState CalculateState(int playerLevel, bool premiumOwned)
    {
        if (data.claimed)
            return RewardState.Claimed;

        if (data.track == RewardTrack.Premium && !premiumOwned)
            return RewardState.PremiumLocked;

        if (playerLevel < data.requiredLevel)
            return RewardState.Locked;

        return RewardState.Claimable;
    }

    private void ApplyState(RewardState state)
    {
        bool locked = state == RewardState.Locked || state == RewardState.PremiumLocked;
        bool premiumLocked = state == RewardState.PremiumLocked;
        bool claimable = state == RewardState.Claimable;
        bool claimed = state == RewardState.Claimed;

        if (lockIcon != null) lockIcon.SetActive(locked);
        if (alertIcon != null) alertIcon.SetActive(claimable || premiumLocked);
        if (claimedCheck != null) claimedCheck.SetActive(claimed);
        if (glow != null) glow.SetActive(claimable);

        button.interactable = claimable;

        float alpha = 1f;

        if (locked)
            alpha = 0.45f;
        else if (claimed)
            alpha = 0.55f;

        rewardIcon.color = new Color(1f, 1f, 1f, alpha);

        if (claimableParticles != null)
        {
            if (claimable) claimableParticles.Play();
            else claimableParticles.Stop();
        }

        if (animator != null)
        {
            animator.SetBool("Claimable", claimable);
            animator.SetBool("Claimed", claimed);
        }
    }

    private void Claim()
    {
        if (currentState != RewardState.Claimable)
            return;

        data.claimed = true;
        currentState = RewardState.Claimed;

        if (claimBurstParticles != null)
            claimBurstParticles.Play();

        if (animator != null)
            animator.SetTrigger("Claim");

        ApplyState(currentState);
        onClaim?.Invoke(data);
    }
}