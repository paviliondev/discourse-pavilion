import { registerUnbound } from "discourse-common/lib/helpers";
import { iconHTML } from "discourse-common/lib/icon-library";

registerUnbound('renderProp', function(data, prop) {
  return data[`${prop}_month`];
})