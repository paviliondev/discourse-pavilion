import { ajax } from 'discourse/lib/ajax';
import TopicList from "discourse/models/topic-list";
import User from 'discourse/models/user';
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    return ajax(`/home`);
  },

  setupController(controller, model) {
    let props = {};

    if (model) {
      if (model.members) {
        props['teamMembers'] = model.members.map(u => {
          return User.create(u);
        });
      };

      if (model.topic_list) {
        props['topics'] = TopicList.topicsFrom(this.store, model.topic_list);

        if (props['topics'].length) {
          props['category'] = props['topics'][0].category;
        };
      }

      if (model.about_topic_list) {
        model.about_topic_list.topic_list = model.about_topic_list.home_topic_list;
        props['aboutTopics'] = TopicList.topicsFrom(this.store, model.about_topic_list);
      }
    }

    controller.setProperties(props);
  }
});
