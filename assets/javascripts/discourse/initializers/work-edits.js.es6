import { withPluginApi } from 'discourse/lib/plugin-api';
import Composer from 'discourse/models/composer';
import { observes } from "discourse-common/utils/decorators";

export default {
  name: 'work-edits',
  initialize() {
    withPluginApi('0.8.23', api => {
      api.modifyClass('controller:topic', {
        @observes('editingTopic')
        setEditingTopicOnModel() {
          this.set('model.editingTopic', this.get('editingTopic'));
        }
      })
    })
  }
}