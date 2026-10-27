import { createElement } from "lwc";
import PxDemos from "c/pxDemos";
import PxDemoLimits from "c/pxDemoLimits";
import PxDemoRouter from "c/pxDemoRouter";
import PxDemoRetry from "c/pxDemoRetry";
import PxDemoSeat from "c/pxDemoSeat";
import { tokenize } from "c/pxCodeViewer";
import runLimitsArena from "@salesforce/apex/DemoController.runLimitsArena";
import routeShipmentEvents from "@salesforce/apex/DemoController.routeShipmentEvents";
import runPaymentSync from "@salesforce/apex/DemoController.runPaymentSync";
import prepareSeatRace from "@salesforce/apex/DemoController.prepareSeatRace";
import bookSeat from "@salesforce/apex/DemoController.bookSeat";
import seatRaceResult from "@salesforce/apex/DemoController.seatRaceResult";

jest.mock(
  "@salesforce/apex/DemoController.runLimitsArena",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DemoController.routeShipmentEvents",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DemoController.runPaymentSync",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DemoController.prepareSeatRace",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DemoController.bookSeat",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DemoController.seatRaceResult",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/DemoController.getSource",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

function flush() {
  // eslint-disable-next-line @lwc/lwc/no-async-operation
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function mount(name, Ctor) {
  const element = createElement(name, { is: Ctor });
  document.body.appendChild(element);
  return element;
}

afterEach(() => {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
  jest.clearAllMocks();
});

describe("tokenize", () => {
  it("classifies keywords, strings, comments and types", () => {
    const [line] = tokenize("public String s = 'hi'; // note");
    const kinds = Object.fromEntries(
      line.tokens.filter((t) => t.cls).map((t) => [t.text, t.cls])
    );
    expect(kinds.public).toBe("t-keyword");
    expect(kinds.String).toBe("t-type");
    expect(kinds["'hi'"]).toBe("t-string");
    expect(kinds["// note"]).toBe("t-comment");
  });

  it("carries block comments across lines", () => {
    const lines = tokenize("/**\n * doc\n */\nclass A {}");
    expect(lines[1].tokens[0].cls).toBe("t-comment");
    expect(lines[3].tokens.find((t) => t.text === "class").cls).toBe(
      "t-keyword"
    );
  });
});

describe("c-px-demos", () => {
  it("switches demos and toggles the live source viewer", async () => {
    const element = mount("c-px-demos", PxDemos);
    expect(element.shadowRoot.querySelector("c-px-demo-limits")).not.toBeNull();
    element.shadowRoot.querySelector('[data-key="seat"]').click();
    await flush();
    expect(element.shadowRoot.querySelector("c-px-demo-seat")).not.toBeNull();
    element.shadowRoot
      .querySelector('[data-name="SeatBookingService"]')
      .click();
    await flush();
    expect(element.shadowRoot.querySelector("c-px-code-viewer").className).toBe(
      "SeatBookingService"
    );
  });
});

describe("c-px-demo-limits", () => {
  it("shows meters and the halt explanation", async () => {
    runLimitsArena.mockResolvedValue({
      recordCount: 200,
      queryLimit: 100,
      dmlLimit: 150,
      bulkified: {
        name: "bulkified",
        records: 200,
        processed: 200,
        queries: 1,
        dmlStatements: 1,
        cpuMs: 80,
        halted: false,
        queriesNeeded: 1,
        dmlNeeded: 1
      },
      naive: {
        name: "naive",
        records: 200,
        processed: 93,
        queries: 93,
        dmlStatements: 93,
        cpuMs: 470,
        halted: true,
        queriesNeeded: 200,
        dmlNeeded: 200
      }
    });
    const element = mount("c-px-demo-limits", PxDemoLimits);
    element.shadowRoot.querySelector(".px-run").click();
    await flush();
    expect(runLimitsArena).toHaveBeenCalledWith({ recordCount: 200 });
    const cards = element.shadowRoot.querySelectorAll(".card");
    expect(cards[0].textContent).toContain("within limits");
    expect(cards[1].textContent).toContain("would crash");
    expect(cards[1].textContent).toContain("Too many SOQL queries: 101");
  });
});

describe("c-px-demo-router", () => {
  it("builds a sequence and renders the trace", async () => {
    routeShipmentEvents.mockResolvedValue([
      {
        index: 1,
        type: "Created",
        version: 1,
        handler: "CreatedHandler",
        outcome: "applied",
        message: "ok",
        statusAfter: "Created",
        versionAfter: 1
      },
      {
        index: 2,
        type: "Created",
        version: 1,
        outcome: "stale",
        message: "Ignored",
        statusAfter: "Created",
        versionAfter: 1
      }
    ]);
    const element = mount("c-px-demo-router", PxDemoRouter);
    element.shadowRoot.querySelector("button:last-of-type").click();
    element.shadowRoot.querySelector('[data-preset="happy"]').click();
    element.shadowRoot.querySelector('[data-type="Teleported"]').click();
    await flush();
    expect(element.shadowRoot.querySelectorAll(".queue li")).toHaveLength(5);
    element.shadowRoot.querySelector(".px-run").click();
    await flush();
    const sent = JSON.parse(routeShipmentEvents.mock.calls[0][0].eventsJson);
    expect(sent[4]).toEqual({ type: "Teleported", version: 5 });
    expect(element.shadowRoot.querySelectorAll("tbody tr")).toHaveLength(2);
    expect(element.shadowRoot.querySelector("tbody").textContent).toContain(
      "stale, ignored"
    );
  });
});

describe("c-px-demo-retry", () => {
  it("runs the chosen scenario and shows the outcome", async () => {
    runPaymentSync.mockResolvedValue({
      outcome: "NEEDS_HUMAN",
      summary: "A person needs to look at this payment.",
      attempts: [
        {
          attempt: 1,
          statusCode: 402,
          classification: "permanent",
          action: "Routed"
        }
      ]
    });
    const element = mount("c-px-demo-retry", PxDemoRetry);
    element.shadowRoot.querySelector('[data-key="declined"]').click();
    await flush();
    element.shadowRoot.querySelector(".px-run").click();
    await flush();
    expect(runPaymentSync).toHaveBeenCalledWith({ scenario: "declined" });
    expect(element.shadowRoot.querySelector(".summary").textContent).toContain(
      "routed to a person"
    );
  });
});

describe("c-px-demo-seat", () => {
  it("fires both bookings at once and explains an overbooking", async () => {
    prepareSeatRace.mockResolvedValue("seat1");
    bookSeat.mockImplementation(({ buyer }) =>
      Promise.resolve({ buyer, booked: true, seatsSeen: 1 })
    );
    seatRaceResult.mockResolvedValue({
      overbooked: true,
      seatsLeft: 0,
      bookings: [{}, {}]
    });
    const element = mount("c-px-demo-seat", PxDemoSeat);
    element.shadowRoot.querySelector(".px-run").click();
    await flush();
    await flush();
    expect(prepareSeatRace).toHaveBeenCalledWith({ useLocking: false });
    expect(bookSeat).toHaveBeenCalledTimes(2);
    expect(element.shadowRoot.querySelector(".verdict").textContent).toContain(
      "Overbooked: 2 bookings"
    );
  });

  it("explains the locked outcome", async () => {
    prepareSeatRace.mockResolvedValue("seat2");
    bookSeat.mockImplementation(({ buyer }) =>
      Promise.resolve({
        buyer,
        booked: buyer === "Ben",
        seatsSeen: buyer === "Ben" ? 1 : 0
      })
    );
    seatRaceResult.mockResolvedValue({
      overbooked: false,
      seatsLeft: 0,
      bookings: [{}]
    });
    const element = mount("c-px-demo-seat", PxDemoSeat);
    element.shadowRoot.querySelector('[data-locking="on"]').click();
    await flush();
    element.shadowRoot.querySelector(".px-run").click();
    await flush();
    await flush();
    expect(prepareSeatRace).toHaveBeenCalledWith({ useLocking: true });
    expect(element.shadowRoot.querySelector(".lanes").textContent).toContain(
      "sold out"
    );
    expect(element.shadowRoot.querySelector(".verdict").textContent).toContain(
      "no oversell"
    );
  });
});
