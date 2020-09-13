import UserCardContents from 'discourse/components/user-card-contents';
import { getURLWithCDN } from "discourse-common/lib/get-url";
import { alias } from "@ember/object/computed";
import { isEmpty } from "@ember/utils";

export default UserCardContents.extend({
  elementId: null,
  layoutName: 'components/user-card-contents',
  visible: true,
  username: alias('user.username'),

  didInsertElement() {
    const url = this.get("user.card_background_upload_url");
    const bg = isEmpty(url)
      ? ""
      : `url(${getURLWithCDN(url)})`;
    this.element.style.backgroundImage = bg;
  },

  willDestroyElement() {
  },

  keyUp() {
  },

  cleanUp() {
  }
});