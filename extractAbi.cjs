const fs = require("fs-extra");
const path = require("path");

// Foundry compilation output directory
const OUT_DIR = path.join(__dirname, "out");
// Frontend ABI storage directory
const FRONTEND_ABI_DIR = path.join(__dirname, "frontend", "abis");

// Ensure frontend ABI directory exists
fs.ensureDirSync(FRONTEND_ABI_DIR);

// Get command line arguments (excluding node and script path)
const contractsToExport = process.argv.slice(2);

if (contractsToExport.length === 0) {
  console.error("Please specify at least one contract name, e.g.: node extractAbi.js DuxPair DuxRouter");
  process.exit(1);
}

contractsToExport.forEach(contractName => {
  const jsonPath = path.join(OUT_DIR, `${contractName}.sol`, `${contractName}.json`);
  if (!fs.existsSync(jsonPath)) {
    console.warn(`File not found: ${jsonPath}`);
    return;
  }

  const jsonData = fs.readJsonSync(jsonPath);
  const abi = jsonData.abi;
  if (!abi) {
    console.warn(`ABI not found in file: ${jsonPath}`);
    return;
  }

  const outPath = path.join(FRONTEND_ABI_DIR, `${contractName}.json`);
  fs.writeJsonSync(outPath, abi, { spaces: 2 });
  console.log(`ABI exported: ${outPath}`);
});
