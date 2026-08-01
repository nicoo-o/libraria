<#
.SYNOPSIS
  Publie Libraria sur GitHub et déclenche la première Release automatisée (APK + build Windows).

.DESCRIPTION
  Fait tout d'un coup, à lancer depuis le terminal VS Code, à la racine du projet :
    1. Vérifie que git et gh (GitHub CLI) sont installés, et que gh est authentifié.
    2. Initialise le dépôt git local si besoin, fait un commit initial.
    3. Crée le repository sur GitHub (ou réutilise le remote 'origin' s'il existe déjà) et pousse le code.
    4. Autorise le GITHUB_TOKEN des Actions à écrire (nécessaire pour que le workflow puisse
       publier une Release — évite d'aller cliquer dans Settings > Actions manuellement).
    5. Crée et pousse un tag de version, ce qui déclenche automatiquement le pipeline
       .github/workflows/ci.yml (tests -> build APK + Windows -> publication de la Release).

  Ce script ne fait AUCUN build Flutter local : tout se passe sur GitHub Actions.
  Peut être relancé sans risque (il détecte ce qui existe déjà et saute les étapes déjà faites).

.PARAMETER RepoName
  Nom du repository à créer sur GitHub. Par défaut : libraria

.PARAMETER Visibility
  Visibilité du repository : public ou private. Par défaut : public
  (doit être public pour que les testeurs téléchargent la Release sans invitation)

.PARAMETER Tag
  Tag de version à créer pour déclencher la release. Par défaut : v0.1.0
  Relance le script avec un tag différent (ex. -Tag v0.1.1) pour publier une nouvelle version.

.EXAMPLE
  .\setup-github-release.ps1

.EXAMPLE
  .\setup-github-release.ps1 -RepoName libraria -Visibility private -Tag v0.2.0
#>

param(
    [string]$RepoName = "libraria",
    [ValidateSet("public", "private")]
    [string]$Visibility = "public",
    [string]$Tag = "v0.1.0"
)

function Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Ok   { param([string]$Msg) Write-Host "    OK - $Msg" -ForegroundColor Green }
function Warn { param([string]$Msg) Write-Host "    ATTENTION - $Msg" -ForegroundColor Yellow }
function Fail { param([string]$Msg) Write-Host "    ECHEC - $Msg" -ForegroundColor Red; exit 1 }

# ------------------------------------------------------------------
# 1. Prérequis
# ------------------------------------------------------------------
Step "Vérification des outils requis"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "git n'est pas installé ou pas dans le PATH."
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Warn "GitHub CLI (gh) n'est pas installé."
    Write-Host "    Installe-le puis relance ce script :  winget install GitHub.cli" -ForegroundColor Yellow
    exit 1
}
Ok "git et gh sont disponibles"

gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Warn "Tu n'es pas connecté à GitHub CLI. Lancement de la connexion..."
    gh auth login
    if ($LASTEXITCODE -ne 0) { Fail "Connexion GitHub CLI annulée ou échouée." }
}
Ok "Authentifié sur GitHub CLI"

if (-not (Test-Path "pubspec.yaml")) {
    Warn "Aucun pubspec.yaml ici — vérifie que tu es bien à la racine du projet Libraria."
}

# ------------------------------------------------------------------
# 2. Dépôt git local
# ------------------------------------------------------------------
Step "Dépôt Git local"

if (-not (Test-Path ".git")) {
    git init | Out-Null
    git branch -M main
    Ok "Dépôt Git initialisé (branche main)"
} else {
    Ok "Dépôt Git déjà présent"
}

git add -A
$pending = git status --porcelain
if ($pending) {
    git commit -m "Publication automatisée : release Libraria" | Out-Null
    Ok "Commit créé"
} else {
    Ok "Rien de nouveau à committer"
}

# ------------------------------------------------------------------
# 3. Repository GitHub distant
# ------------------------------------------------------------------
Step "Repository GitHub"

$existingRemotes = git remote
if ($existingRemotes -contains "origin") {
    Ok "Le remote 'origin' existe déjà"
    git push -u origin main
    if ($LASTEXITCODE -ne 0) { Fail "Le push vers origin/main a échoué." }
} else {
    gh repo create $RepoName --$Visibility --source=. --remote=origin --push
    if ($LASTEXITCODE -ne 0) {
        Fail "Création du repository '$RepoName' échouée (nom déjà pris ? relance avec -RepoName autrechose)."
    }
    Ok "Repository '$RepoName' créé et code poussé"
}

$repoFullName = gh repo view --json nameWithOwner -q ".nameWithOwner"
if (-not $repoFullName) { Fail "Impossible de déterminer le repository distant." }
Ok "Repository distant : $repoFullName"

# ------------------------------------------------------------------
# 4. Permissions d'écriture pour les Actions (sinon la Release ne peut pas être publiée)
# ------------------------------------------------------------------
Step "Activation des permissions d'écriture pour GITHUB_TOKEN"

gh api -X PUT "repos/$repoFullName/actions/permissions/workflow" `
    -f default_workflow_permissions=write `
    -F can_approve_pull_request_reviews=false *> $null

if ($LASTEXITCODE -ne 0) {
    Warn "Impossible de régler ça automatiquement (droits insuffisants ?)."
    Write-Host "    A faire à la main : Settings > Actions > General > Workflow permissions > 'Read and write permissions'" -ForegroundColor Yellow
} else {
    Ok "GITHUB_TOKEN autorisé à créer des Releases"
}

# ------------------------------------------------------------------
# 5. Tag de version -> déclenche automatiquement le pipeline de release
# ------------------------------------------------------------------
Step "Tag de version $Tag"

$existingTag = git tag -l $Tag
if ($existingTag) {
    Warn "Le tag $Tag existe déjà localement. Relance avec -Tag v0.1.1 (ou autre) pour publier une nouvelle version."
} else {
    git tag $Tag
    git push origin $Tag
    if ($LASTEXITCODE -ne 0) { Fail "Le push du tag a échoué." }
    Ok "Tag $Tag poussé — le pipeline (tests -> builds -> Release) se lance automatiquement"
}

# ------------------------------------------------------------------
Step "Terminé"
Write-Host "Suivre le build en direct : https://github.com/$repoFullName/actions" -ForegroundColor Cyan
Write-Host "La Release apparaîtra ici (~10-15 min)  : https://github.com/$repoFullName/releases" -ForegroundColor Cyan
