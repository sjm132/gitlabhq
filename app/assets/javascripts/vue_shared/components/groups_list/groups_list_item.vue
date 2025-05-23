<script>
import { GlIcon, GlBadge, GlTooltipDirective } from '@gitlab/ui';
import uniqueId from 'lodash/uniqueId';

import { createAlert } from '~/alert';
import GroupListItemDeleteModal from '~/vue_shared/components/groups_list/group_list_item_delete_modal.vue';
import axios from '~/lib/utils/axios_utils';
import { VISIBILITY_TYPE_ICON, GROUP_VISIBILITY_TYPE } from '~/visibility_level/constants';
import { ACCESS_LEVEL_LABELS, ACCESS_LEVEL_NO_ACCESS_INTEGER } from '~/access_level/constants';
import { __ } from '~/locale';
import { numberToMetricPrefix } from '~/lib/utils/number_utils';
import { ACTION_EDIT, ACTION_DELETE } from '~/vue_shared/components/list_actions/constants';
import {
  TIMESTAMP_TYPES,
  TIMESTAMP_TYPE_CREATED_AT,
} from '~/vue_shared/components/resource_lists/constants';
import ListItem from '~/vue_shared/components/resource_lists/list_item.vue';
import ListItemStat from '~/vue_shared/components/resource_lists/list_item_stat.vue';
import { renderDeleteSuccessToast, deleteParams } from '~/vue_shared/components/groups_list/utils';
import GroupListItemPreventDeleteModal from './group_list_item_prevent_delete_modal.vue';
import GroupListItemInactiveBadge from './group_list_item_inactive_badge.vue';

export default {
  i18n: {
    subgroups: __('Subgroups'),
    projects: __('Projects'),
    directMembers: __('Direct members'),
    deleteErrorMessage: __(
      'An error occurred deleting the group. Please refresh the page to try again.',
    ),
  },
  components: {
    ListItem,
    ListItemStat,
    GlIcon,
    GlBadge,
    GroupListItemPreventDeleteModal,
    GroupListItemDeleteModal,
    GroupListItemInactiveBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    group: {
      type: Object,
      required: true,
    },
    showGroupIcon: {
      type: Boolean,
      required: false,
      default: false,
    },
    listItemClass: {
      type: [String, Array, Object],
      required: false,
      default: '',
    },
    timestampType: {
      type: String,
      required: false,
      default: TIMESTAMP_TYPE_CREATED_AT,
      validator(value) {
        return TIMESTAMP_TYPES.includes(value);
      },
    },
  },
  data() {
    return {
      isDeleteModalVisible: false,
      isDeleteLoading: false,
      modalId: uniqueId('groups-list-item-modal-id-'),
    };
  },
  computed: {
    visibility() {
      return this.group.visibility;
    },
    visibilityIcon() {
      return VISIBILITY_TYPE_ICON[this.visibility];
    },
    visibilityTooltip() {
      return GROUP_VISIBILITY_TYPE[this.visibility];
    },
    accessLevel() {
      return this.group.accessLevel?.integerValue;
    },
    accessLevelLabel() {
      return ACCESS_LEVEL_LABELS[this.accessLevel];
    },
    shouldShowAccessLevel() {
      return this.accessLevel !== undefined && this.accessLevel !== ACCESS_LEVEL_NO_ACCESS_INTEGER;
    },
    groupIconName() {
      return this.group.parent ? 'subgroup' : 'group';
    },
    descendantGroupsCount() {
      return numberToMetricPrefix(this.group.descendantGroupsCount);
    },
    projectsCount() {
      return numberToMetricPrefix(this.group.projectsCount);
    },
    groupMembersCount() {
      return numberToMetricPrefix(this.group.groupMembersCount);
    },
    actions() {
      return {
        [ACTION_EDIT]: {
          href: this.group.editPath,
        },
        [ACTION_DELETE]: {
          action: this.onActionDelete,
        },
      };
    },
    hasActionDelete() {
      return this.group.availableActions?.includes(ACTION_DELETE);
    },
  },
  methods: {
    onActionDelete() {
      this.isDeleteModalVisible = true;
    },
    onModalChange(isVisible) {
      this.isDeleteModalVisible = isVisible;
    },
    async onDeleteModalConfirm() {
      this.isDeleteLoading = true;

      try {
        await axios.delete(`/${this.group.fullPath}`, {
          params: deleteParams(this.group),
        });
        this.$emit('refetch');
        renderDeleteSuccessToast(this.group);
      } catch (error) {
        createAlert({ message: this.$options.i18n.deleteErrorMessage, error, captureError: true });
      } finally {
        this.isDeleteLoading = false;
      }
    },
  },
};
</script>

<template>
  <list-item
    :resource="group"
    :show-icon="showGroupIcon"
    :icon-name="groupIconName"
    :actions="actions"
    :list-item-class="listItemClass"
    :timestamp-type="timestampType"
  >
    <template #children-toggle>
      <slot name="children-toggle"></slot>
    </template>
    <template #avatar-meta>
      <gl-icon
        v-if="visibility"
        v-gl-tooltip="visibilityTooltip"
        :name="visibilityIcon"
        variant="subtle"
      />
      <gl-badge v-if="shouldShowAccessLevel" class="gl-block" data-testid="user-access-role">{{
        accessLevelLabel
      }}</gl-badge>
    </template>

    <template #stats>
      <group-list-item-inactive-badge :group="group" />
      <list-item-stat
        :tooltip-text="$options.i18n.subgroups"
        icon-name="subgroup"
        :stat="descendantGroupsCount"
        data-testid="subgroups-count"
      />
      <list-item-stat
        :tooltip-text="$options.i18n.projects"
        icon-name="project"
        :stat="projectsCount"
        data-testid="projects-count"
      />
      <list-item-stat
        :tooltip-text="$options.i18n.directMembers"
        icon-name="users"
        :stat="groupMembersCount"
        data-testid="members-count"
      />
    </template>

    <template v-if="hasActionDelete" #footer>
      <group-list-item-prevent-delete-modal
        v-if="group.isLinkedToSubscription"
        :visible="isDeleteModalVisible"
        :modal-id="modalId"
        @change="onModalChange"
      />
      <group-list-item-delete-modal
        v-else
        :visible="isDeleteModalVisible"
        :modal-id="modalId"
        :phrase="group.fullName"
        :confirm-loading="isDeleteLoading"
        :group="group"
        @confirm.prevent="onDeleteModalConfirm"
        @change="onModalChange"
      />
    </template>

    <template #children>
      <slot name="children"></slot>
    </template>
  </list-item>
</template>
