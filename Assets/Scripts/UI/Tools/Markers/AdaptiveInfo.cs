﻿using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using MapLua;
using Ozone.UI;

namespace EditMap
{
	public class AdaptiveInfo : MonoBehaviour
	{

		[Header("UI")]
		public GameObject TogglePrefab;
		public GameObject TitlePrefab;
		public GameObject TitleDescPrefab;
		public Transform ArmyTooglePivot;
		public Transform CustomTablesPivot;

		public HashSet<GameObject> CreatedObjects;

		Dictionary<string, UiToggle> Toggles = new Dictionary<string, UiToggle>();


		private void OnEnable()
		{
			Generate();
		}

		void Generate()
		{

			if (!MapLuaParser.Current.TablesLuaFile.IsLoaded)
				return;

			Toggles = new Dictionary<string, UiToggle>();
			ScenarioLua.ScenarioInfo ScenarioData = MapLuaParser.Current.ScenarioLuaFile.Data;

			for (int c = 0; c < ScenarioData.Configurations.Length; c++)
			{
				for (int t = 0; t < ScenarioData.Configurations[c].Teams.Length; t++)
				{
					for (int a = 0; a < ScenarioData.Configurations[c].Teams[t].Armys.Count; a++)
					{
						if (ScenarioData.Configurations[c].Teams[t].Armys[a].Data != null)
						{
							GameObject NewToggleObj = Instantiate(TogglePrefab, ArmyTooglePivot.parent);
							NewToggleObj.transform.SetSiblingIndex(ArmyTooglePivot.GetSiblingIndex());
							NewToggleObj.SetActive(true);

							UiToggle NewToggle = NewToggleObj.GetComponent<UiToggle>();
							NewToggle.Set(false, ScenarioData.Configurations[c].Teams[t].Armys[a].Data.Name + " (" + ScenarioData.Configurations[c].Teams[t].name + ")");
						}
					}
				}
			}


			TablesLua.TablesInfo TablesData = MapLuaParser.Current.TablesLuaFile.Data;
			for(int i = 0; i < TablesData.AllTables.Count; i++)
			{
				CreateTitle(TablesData.AllTables[i].Key);

				if (TablesData.AllTables[i].OneDimension)
				{
					GameObject NewToggleObj = Instantiate(TogglePrefab, ArmyTooglePivot.parent);
					NewToggleObj.transform.SetSiblingIndex(CustomTablesPivot.GetSiblingIndex());
					NewToggleObj.SetActive(true);

					UiToggle NewToggle = NewToggleObj.GetComponent<UiToggle>();
					NewToggle.Set(false, TablesData.AllTables[i].Key);
				}
				else
				{
					for(int j = 0; j < TablesData.AllTables[i].Values.Length; j++)
					{
						GameObject NewToggleObj = Instantiate(TogglePrefab, ArmyTooglePivot.parent);
						NewToggleObj.transform.SetSiblingIndex(CustomTablesPivot.GetSiblingIndex());
						NewToggleObj.SetActive(true);

						UiToggle NewToggle = NewToggleObj.GetComponent<UiToggle>();
						NewToggle.Set(false, (j + 1).ToString()); // TablesData.AllTables[i].Key + " " + 

					}
				}
			}
		}

		public void UpdateSelection()
		{

		}

		void CreateTitle(string name)
		{
			GameObject Prefab = TitlePrefab;
			string Name = name;
			string Desc = "";

			switch (name)
			{
				case "crazyrushOneMex":
					Prefab = TitleDescPrefab;
					Name = "Crazyrush";
					Desc = "One mex per player";
					break;
				case "DuplicateListMex":
					Prefab = TitleDescPrefab;
					Name = "Duplicate List Mex";
					Desc = "Additional crazyrush mex";
					break;
				case "extramass":
					Prefab = TitleDescPrefab;
					Name = "Extra Mass";
					Desc = "Additional mex in starting locations";
					break;
			}



			GameObject NewTitleObj = Instantiate(Prefab, ArmyTooglePivot.parent);
			NewTitleObj.transform.SetSiblingIndex(CustomTablesPivot.GetSiblingIndex());
			NewTitleObj.SetActive(true);
			NewTitleObj.GetComponent<Text>().text = FormatTableName(name);

			if (!string.IsNullOrEmpty(Desc))
			{
				NewTitleObj.GetComponent<UiTitle>().Subtitle.text = Desc;
			}

		}

		static string FormatTableName(string name)
		{
			name = name.Replace("mass", "Mass");
			name = name.Replace("mex", "Mex");
			name = name.Replace("hydro", "Hydro");

			for(int i = 0; i < name.Length; i++)
			{
				if (char.IsUpper(name[i]))
				{
					name = name.Insert(i, " ");
					i++;
				}
				else if(i == 0)
				{
					char New = char.ToUpper(name[i]);
					name = name.Remove(0, 1);
					name = New + name;
				}
			}
			return name;
		}

		public void CreateTablesFile()
		{
			GenericPopup.ShowPopup(GenericPopup.PopupTypes.TriButton, "Creating Tables", "Replace current script.lua file?\nThis can't be undone.",
				"Yes", ReplaceScript,
				"No", NoScript,
				"Cancel", Cancel
				);
		}

		void ReplaceScript()
		{

		}

		void NoScript()
		{

		}

		void Cancel()
		{

		}
	}
}
