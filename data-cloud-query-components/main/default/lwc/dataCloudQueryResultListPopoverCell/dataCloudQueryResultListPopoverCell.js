/**
 * Created by dsingh on 19.11.25.
 */

import { LightningElement, api } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import POPPERJS from "@salesforce/resourceUrl/DCQR_PopperJsLib"; // Static Resource name: popperjs

//THIS VARIABLE IS USED TO SIMULATE SINGLETON PATTERN FOR POPOVER.
//TO ENFORCE ONLY ONE INSTANCE OF POPOVER OPENED AT A TIME
let LAST_OPENED_POPOVER_TOGGLE_CALLBACK;

export default class DataCloudQueryResultListPopoverCell extends LightningElement {
  @api value;
  @api popoverTitle = "Details";
  @api popoverIcon = "utility:info";
  @api popoverWidth;
  @api popoverHeight;
  @api items;
  @api rowData;

  _popoverItems = [];

  isPopoverOpen = false;
  popperInitialized = false;
  popperInstance = null;

  connectedCallback() {
    this.popoverItems = this.items;

    //initialize popper.js
    if (!this.popperInitialized) {
      this.loadPopperJs();
    }
  }

  set popoverItems(data) {
    if (data && Array.isArray(data)) {
      this._popoverItems = data.map((item) => ({
        ...item,
        //resolve the field value
        value: this?.rowData[item.value?.fieldName],

        // Inject conditional rendering properties
        isRichText: item.type === "richtext",
        isNumber: item.type === "number" || item.type === "integer",
        isCurrency: item.type === "currency",
        isDate: item.type === "date",
        isDateTime: item.type === "datetime",
        isDefault: ![
          "richtext",
          "number",
          "integer",
          "currency",
          "date",
          "datetime",
        ].includes(item.type),
        typeAttributes: item.typeAttributes || {},
      }));
    } else {
      this._popoverItems = [];
    }
  }

  get popoverItems() {
    return this._popoverItems;
  }

  // Load Popper.js static resource
  loadPopperJs() {
    loadScript(this, POPPERJS)
      .then(() => {
        this.popperInitialized = true;
      })
      .catch((error) => {
        console.error("Error loading Popper.js:", error);
      });
  }

  // Computed style for popover width and height
  get popoverStyle() {
    let style = "position: absolute; z-index: 1000;";
    if (this.popoverWidth) {
      style += ` width: ${this.popoverWidth}px;`;
    }
    if (this.popoverHeight) {
      style += ` height: ${this.popoverHeight + 50}px;`;
    }
    return style;
  }

  get popoverContentStyle() {
    let style = "";
    if (this.popoverWidth) {
      style += ` width: ${this.popoverWidth}px;`;
    }
    if (this.popoverHeight) {
      style += ` height: ${this.popoverHeight}px;`;
    }

    return style;
  }

  get showPopoverButton() {
    return this._popoverItems && this._popoverItems.length > 0;
  }

  togglePopover = () => {
    this.isPopoverOpen = !this.isPopoverOpen;

    if (this.isPopoverOpen) {
      setTimeout(() => {
        //If  last opened popover is not closed then first toggle its visibility
        if (LAST_OPENED_POPOVER_TOGGLE_CALLBACK) {
          LAST_OPENED_POPOVER_TOGGLE_CALLBACK();
        }

        this.initializePopper();

        //Assigned the toggle callback once the popover is initialized
        LAST_OPENED_POPOVER_TOGGLE_CALLBACK = this.togglePopover;
      }, 0);
    } else {
      this.destroyPopper();
      //remove the toggle callback instance from the call back
      LAST_OPENED_POPOVER_TOGGLE_CALLBACK = null;
    }
  };

  // Handles clicks outside the popover to close it
  handleOutsideClick(event) {
    const popover = this.template.querySelector(".popper-element");
    const reference = this.template.querySelector(".popper-reference-element");

    if (
      popover &&
      reference &&
      !popover.contains(event.target) &&
      !reference.contains(event.target)
    ) {
      this.isPopoverOpen = false;
      this.destroyPopper();
      document.removeEventListener("click", this.handleOutsideClick.bind(this));
    }
  }

  // Initializes the Popper.js instance
  initializePopper() {
    if (!this.popperInitialized) {
      console.error("Popper.js not loaded.");
      return;
    }

    const referenceElement = this.template.querySelector(
      ".popper-reference-element"
    );
    const popperElement = this.template.querySelector(".popper-element");

    if (referenceElement && popperElement) {
      this.popperInstance = Popper.createPopper(
        referenceElement,
        popperElement,
        {
          placement: "auto", // SETTING THE POPPER PLACEMENT HERE
          strategy: "fixed",
          modifiers: [
            {
              name: "offset",
              options: {
                offset: [0, 8],
              },
            },
            // Custom modifier to ensure the SLDS nubbin class is correct based on final placement
            {
              name: "updateNubbinClass",
              enabled: true,
              phase: "beforeWrite",
              fn: ({ state }) => {
                const side = state.placement.split("-")[0]; // 'bottom'
                let nubbinClass = "";

                if (side === "bottom") {
                  nubbinClass = "slds-nubbin_top";
                } else if (side === "top") {
                  nubbinClass = "slds-nubbin_bottom";
                } else if (side === "right") {
                  nubbinClass = "slds-nubbin_left";
                } else if (side === "left") {
                  nubbinClass = "slds-nubbin_right";
                }

                // Remove previous nubbin class (e.g., slds-nubbin_top) and add the correct one
                popperElement.className = popperElement.className.replace(
                  /slds-nubbin_\w+-?\w*/g,
                  ""
                );
                if (nubbinClass) {
                  popperElement.classList.add(nubbinClass);
                }
              },
              requires: ["popperOffsets"],
            },
          ],
        }
      );
    }
  }

  // Cleans up the Popper.js instance
  destroyPopper() {
    if (this.popperInstance) {
      this.popperInstance.destroy();
      this.popperInstance = null;
    }
  }

  disconnectedCallback() {
    this.destroyPopper();
  }
}
