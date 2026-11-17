# Reusable privacy implementation notes

ATT denial does not prohibit advertising. On iOS, ATT governs IDFA tracking; Google Mobile Ads documents that it omits IDFA after denial while ads may still be requested. UMP regional consent and `canRequestAds()` remain independent requirements.

Firebase Analytics is optional and starts disabled until the user separately opts in. Firebase ad storage, advertising user data, and ad personalization are denied, and generated iOS projects disable IDFV collection. Do not infer analytics consent from ATT status. Review console links, audiences, Google signals, data sharing, regional requirements, privacy disclosures, and actual network behavior per app.

On background/resume, cached banner/rewarded ads are disposed, late callbacks invalidated, and UMP/ATT state refreshed. Verify on physical devices before claiming compliance.
