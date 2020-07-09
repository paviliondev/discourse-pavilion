import DiscourseURL from 'discourse/lib/url';
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  classNames: 'about-topic',

  @discourseComputed('topic.posters')
  displayUser(posters) {
    return posters[0].user;
  },

  click() {
    DiscourseURL.routeTo(this.get('topic.url'));
  }
});