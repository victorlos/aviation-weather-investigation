"""
Download the BTS Master Coordinate table (T_MASTER_CORD) with Selenium,
by driving a real Chrome browser: select all fields, click Download,
wait for the zip, and extract the CSV.

Setup:
    pip install selenium
    (Selenium 4.6+ downloads the right ChromeDriver automatically;
     you only need Google Chrome installed.)

Usage:
    python download_t_master_cord_selenium.py

Output:
    data/bts/T_MASTER_CORD.csv
"""

import time
import zipfile
from pathlib import Path

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

PAGE_URL = (
    "https://www.transtats.bts.gov/DL_SelectFields.aspx"
    "?gnoyr_VQ=FLL&QO_fu146_anzr=N8vn6v10%20f722146%20gnoyr5"
)
OUT_DIR = Path("data/bts").resolve()
DOWNLOAD_DIR = OUT_DIR / "_downloads"
OUT_CSV = OUT_DIR / "T_MASTER_CORD.csv"

HEADLESS = False        # set True to run without opening a browser window
TIMEOUT_SECONDS = 180

# checkboxes that are page options, not table columns
OPTION_KEYWORDS = ("zip", "allgroup", "merge", "null", "doc", "allvar", "selectall")


def make_driver() -> webdriver.Chrome:
    options = webdriver.ChromeOptions()
    if HEADLESS:
        options.add_argument("--headless=new")
    options.add_argument("--window-size=1400,1000")
    options.add_experimental_option("prefs", {
        "download.default_directory": str(DOWNLOAD_DIR),
        "download.prompt_for_download": False,
        "download.directory_upgrade": True,
        "safebrowsing.enabled": True,
    })
    return webdriver.Chrome(options=options)


def is_option_box(el) -> bool:
    ident = ((el.get_attribute("id") or "") + " " + (el.get_attribute("name") or "")).lower()
    return any(k in ident for k in OPTION_KEYWORDS)


def select_all_fields(driver) -> int:
    """Click 'Select all fields' if it exists, then make sure every column box is checked."""
    boxes = driver.find_elements(By.CSS_SELECTOR, "input[type='checkbox']")

    select_all = [
        b for b in boxes
        if any(k in ((b.get_attribute("id") or "") + (b.get_attribute("name") or "")).lower()
               for k in ("allvar", "selectall"))
    ]
    if select_all and not select_all[0].is_selected():
        driver.execute_script("arguments[0].click();", select_all[0])
        time.sleep(1)

    # fallback: tick any column checkbox still unchecked
    checked = 0
    for box in driver.find_elements(By.CSS_SELECTOR, "input[type='checkbox']"):
        if is_option_box(box):
            continue
        if not box.is_selected():
            driver.execute_script("arguments[0].click();", box)
        checked += 1
    return checked


def click_download(driver) -> None:
    xpath = (
        "//button[contains(translate(normalize-space(.), 'DOWNLOAD', 'download'), 'download')]"
        " | //input[(@type='submit' or @type='button') and "
        "contains(translate(@value, 'DOWNLOAD', 'download'), 'download')]"
    )
    button = WebDriverWait(driver, 30).until(EC.element_to_be_clickable((By.XPATH, xpath)))
    driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", button)
    driver.execute_script("arguments[0].click();", button)


def wait_for_zip() -> Path:
    deadline = time.time() + TIMEOUT_SECONDS
    while time.time() < deadline:
        zips = list(DOWNLOAD_DIR.glob("*.zip"))
        in_progress = list(DOWNLOAD_DIR.glob("*.crdownload"))
        if zips and not in_progress:
            return max(zips, key=lambda p: p.stat().st_mtime)
        time.sleep(1)
    raise TimeoutError(f"No zip appeared in {DOWNLOAD_DIR} after {TIMEOUT_SECONDS}s")


def extract_csv(zip_path: Path) -> None:
    with zipfile.ZipFile(zip_path) as z:
        csv_name = next(n for n in z.namelist() if n.lower().endswith("cord.csv"))
        OUT_CSV.write_bytes(z.read(csv_name))
    print(f"[ok] saved {OUT_CSV} (from {csv_name})")


def main():
    DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    for old in DOWNLOAD_DIR.glob("*.zip"):
        old.unlink()

    driver = make_driver()
    try:
        driver.get(PAGE_URL)
        WebDriverWait(driver, 60).until(
            EC.presence_of_element_located((By.CSS_SELECTOR, "input[type='checkbox']"))
        )

        n = select_all_fields(driver)
        print(f"[info] {n} field checkboxes selected")

        click_download(driver)
        print("[info] download clicked, waiting for the file...")

        extract_csv(wait_for_zip())

    except Exception:
        shot = OUT_DIR / "selenium_error.png"
        driver.save_screenshot(str(shot))
        print(f"[failed] screenshot saved to {shot}")
        raise
    finally:
        driver.quit()


if __name__ == "__main__":
    main()
