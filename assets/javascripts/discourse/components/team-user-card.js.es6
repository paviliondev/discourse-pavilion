import {
  default as DiscourseURL,
  userPath,
  groupPath
} from "discourse/lib/url";
import Component from "@ember/component";
import { inject as service } from "@ember/service";

export default Component.extend({
  router: service(),
  classNames: ["team-user-card"],

  actions: {
    showUser(user) {
      DiscourseURL.routeTo(userPath(user.username_lower));
    },

    showGroup(group) {
      DiscourseURL.routeTo(groupPath(group.name));
    }
  }
});