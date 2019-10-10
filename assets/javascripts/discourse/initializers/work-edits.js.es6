import { withPluginApi } from 'discourse/lib/plugin-api';
import Composer from 'discourse/models/composer';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

export default {
  name: 'work-edits',
  initialize() {
    Composer.serializeToTopic('billable_hours', 'topic.billable_hours');
    Composer.serializeToTopic('actual_hours', 'topic.actual_hours');

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