# Stage 15 — Medication Adherence & Longitudinal Health Intelligence

## 1. Medication adherence
- Builds expected dose occurrences from each active medication's explicit `dose_times`, start date and end date.
- Compares expected occurrences against linked patient-reported dose events.
- Distinguishes taken, missed, skipped, overdue (past due without a recorded event), and upcoming.
- Calculates a descriptive adherence percentage from recorded taken/missed/skipped events only; overdue unknowns are not silently counted as missed.
- Displays a recent/upcoming dose timeline and counts in Health Insights.
- Creates a deduplicated in-app warning when an overdue scheduled dose is detected during medication schedule reconciliation; the patient is asked to confirm taken/missed/skipped. This is reconciled when the medication module is opened, not a background clinical escalation service.
- Does not infer clock times from frequency text, mark a dose taken automatically, or recommend what to do after a missed dose.
- Dose-event matching uses a six-hour nearest-event window. This is a matching heuristic, not a clinical dosing window.

## 2. Personal longitudinal neural model
The app now includes a pure-Dart, on-device self-supervised temporal autoencoder:
- Per-patient history is read from the locally decrypted record repository.
- Daily features include heart rate, systolic and diastolic blood pressure components, glucose, temperature, oxygen saturation, weight, respiratory rate, recorded medication adherence events, and encounter counts.
- Numeric features are normalized against that patient's own historical median and median absolute deviation; missing-feature masks are retained.
- Three consecutive observed-day frames are combined into a temporal input window.
- Network topology: 60 input features (three observed-day frames × 10 features/masks) → 40 hidden units → 16-unit latent representation → 40 hidden units → 60 reconstructed features, using tanh activations.
- Self-supervised reconstruction training uses earlier history; the most recent chronological segment is held out for comparison.
- The UI reports only whether the recent record pattern differs from the patient's learned baseline, with the history coverage and limitations visible.
- The model requires at least 20 distinct observed days before it runs.

## 3. Hybrid intelligence boundary
The neural model is one part of the framework's hybrid architecture. Deterministic summaries remain responsible for exact values, units, dates, medication lists, allergies, conditions, provenance and source traceability. The model does not replace the underlying record history.

## 4. Privacy and clinical safety
- All model input is derived from records read from the existing local encrypted vault; no health data is sent to an external AI service.
- Model training and inference execute in the app process on-device.
- No disease diagnosis, clinical risk probability, medication recommendation, dose adjustment, or treatment plan is generated.
- A personal-pattern deviation is not necessarily medically important; missing data, inconsistent measurement technique, unit errors and normal context changes can affect it.
- The current network is self-supervised and is not trained or validated against clinical outcomes. It is an engineering prototype for personal-pattern monitoring, not a clinically validated neural model.
- Model parameters are initialized deterministically and retrained from the available local history when insights are loaded; persistent encrypted model checkpoints and robust background incremental training are future work.
- The feature extractor currently supports selected structured observation types, medication dose events and encounters. OCR/NLP, document classification, semantic search and richer symptom/journal models remain future intelligence work from the original product framework.

## 5. Verification
- Backend schema regression tests and Python compilation are run.
- Flutter unit tests are added for minimum-history gating, model baseline training and medication adherence calculation.
- Flutter/Dart SDK is unavailable in this environment. Analyzer, Dart formatting, Flutter tests, Android/iOS builds, performance profiling and physical-device verification remain pending.
