const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  moduleNameMapper: {
    ...jestConfig.moduleNameMapper,
    // CSS-only modules resolve on the platform but not in Jest's resolver.
    "^c/pxTokens$":
      "<rootDir>/force-app/main/default/lwc/pxTokens/pxTokens.css",
    "^lightning/actions$": "<rootDir>/jest-mocks/lightning/actions.js"
  },
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"]
};
