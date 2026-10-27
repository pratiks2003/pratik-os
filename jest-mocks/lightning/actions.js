// Jest stub: sfdx-lwc-jest does not ship lightning/actions.
export const CloseActionScreenEvent = class CloseActionScreenEvent extends CustomEvent {
  constructor() {
    super("close");
  }
};
