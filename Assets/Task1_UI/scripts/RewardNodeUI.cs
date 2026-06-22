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

    [Header("Shine Effect")]
    [SerializeField] private RectTransform shine;
    [SerializeField] private float shineStartX = -300f;
    [SerializeField] private float shineEndX = 300f;
    [SerializeField] private float shineDuration = 1f;
    [SerializeField] private float shineWaitTime = 2f;

    [Header("Milestone")]
    [SerializeField] private TMP_Text milestoneLevelText;

    [Header("Premium Tick")]
    [SerializeField] private GameObject premiumTick;

    [Header("FX")]
    [SerializeField] private ParticleSystem claimableParticles;
    [SerializeField] private ParticleSystem claimBurstParticles;
    [SerializeField] private Animator animator;

    [Header("Backgrounds")]
    [Tooltip("Default background sprite used for reached (claimable/claimed) cards.")]
    [SerializeField] private Sprite defaultBackgroundSprite;
    [Tooltip("Background sprite used for free-track cards that have been claimed.")]
    [SerializeField] private Sprite claimedFreeBackgroundSprite;

    [Header("Button")]
    [SerializeField] private Button button;

    private BattlePassRewardData data;
    private RewardState currentState;
    private bool premiumOwned;
    private int cachedPlayerLevel;
    private System.Action<BattlePassRewardData> onClaim;

    private float shineTimer;
    private bool shineMoving;
    private bool shineActive;

    public void Setup(
        BattlePassRewardData rewardData,
        int playerLevel,
        bool premiumOwned,
        System.Action<BattlePassRewardData> claimCallback)
    {
        data = rewardData;
        onClaim = claimCallback;
        this.premiumOwned = premiumOwned;
        cachedPlayerLevel = playerLevel;

        rewardNameText.text = data.displayName?.ToUpper() ?? "";
        rewardIcon.sprite = data.icon;

        if (milestoneLevelText != null)
            milestoneLevelText.text = data.requiredLevel.ToString();

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

        shineActive = claimable;
        if (shine != null)
        {
            shine.gameObject.SetActive(claimable);
            if (claimable)
            {
                shineTimer = 0f;
                shineMoving = false;
                shine.anchoredPosition = new Vector2(shineStartX, 0f);
            }
        }
        if (premiumTick != null) premiumTick.SetActive(data.track == RewardTrack.Premium && premiumOwned);

        button.interactable = claimable;

        if (cardBackground != null)
        {
            Sprite bgSprite;
            if (claimed && data.track == RewardTrack.Free && claimedFreeBackgroundSprite != null)
                bgSprite = claimedFreeBackgroundSprite;
            else if (cachedPlayerLevel >= data.requiredLevel)
                bgSprite = defaultBackgroundSprite;
            else
                bgSprite = data.lockedBackground;

            if (bgSprite != null)
                cardBackground.sprite = bgSprite;
            cardBackground.color = Color.white;
        }

        rewardIcon.color = Color.white;

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

    private void Update()
    {
        if (!shineActive || shine == null) return;

        if (!shineMoving)
        {
            shineTimer += Time.deltaTime;
            if (shineTimer >= shineWaitTime)
            {
                shineTimer = 0f;
                shineMoving = true;
            }
            return;
        }

        float t = shineTimer / shineDuration;
        shine.anchoredPosition = new Vector2(Mathf.Lerp(shineStartX, shineEndX, t), 0f);
        shineTimer += Time.deltaTime;

        if (shineTimer >= shineDuration)
        {
            shineTimer = 0f;
            shineMoving = false;
            shine.anchoredPosition = new Vector2(shineStartX, 0f);
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